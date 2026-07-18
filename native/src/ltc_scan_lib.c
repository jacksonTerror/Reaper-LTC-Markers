#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <ctype.h>

#include "ltc.h"
#include "ltc_scan.h"

#define MAX_MAPPINGS 4096
#define MIN_GAP_SEC 1.0
#define DECODE_RATE 48000 /* same as REAtcMARK / libltc-friendly; LTC does not need 96k */
#define READ_SEC 0.25     /* larger disk reads */
#define PROGRESS_EVERY_SEC 2.0

static void write_progress(const char *path, double pos, double total, int matches) {
  FILE *pf;
  double pct;
  if (!path || !path[0]) return;
  pf = fopen(path, "w");
  if (!pf) return;
  if (total < 0.001) total = 0.001;
  pct = 100.0 * pos / total;
  if (pct > 100.0) pct = 100.0;
  if (pct < 0.0) pct = 0.0;
  fprintf(pf, "PROGRESS\t%.3f\t%.3f\t%.1f\t%d\n", pos, total, pct, matches);
  fclose(pf);
}

static void trim(char *s) {
  char *start = s;
  char *e;
  while (*start && isspace((unsigned char)*start)) start++;
  if (start != s) memmove(s, start, strlen(start) + 1);
  e = s + strlen(s);
  while (e > s && isspace((unsigned char)e[-1])) *--e = 0;
}

static int code_to_abs(const char *code, int fps) {
  int hh, mm, ss, ff;
  if (sscanf(code, "%d:%d:%d:%d", &hh, &mm, &ss, &ff) != 4) return -1;
  return (((hh * 60) + mm) * 60 + ss) * fps + ff;
}

static void format_tc(int hours, int mins, int secs, int frame, char *buf, size_t n) {
  snprintf(buf, n, "%02d:%02d:%02d:%02d", hours, mins, secs, frame);
}

typedef struct {
  int abs_frames;
  char name[256];
} Mapping;

typedef struct {
  Mapping items[MAX_MAPPINGS];
  int count;
} MappingTable;

static int load_mappings(const char *path, int fps, MappingTable *table, FILE *log) {
  FILE *f = fopen(path, "r");
  char line[1024];
  int first = 1;
  table->count = 0;
  if (!f) {
    fprintf(log, "LOG\tCould not open mapping CSV: %s\n", path);
    return -1;
  }
  while (fgets(line, sizeof(line), f)) {
    char *comma, smpte_buf[64], name_buf[256];
    char *smpte, *name;
    line[strcspn(line, "\r\n")] = 0;
    if (!line[0]) continue;
    comma = strchr(line, ',');
    if (!comma) continue;
    *comma = 0;
    smpte = line;
    name = comma + 1;
    if (name[0] == '"') {
      size_t len;
      name++;
      len = strlen(name);
      if (len && name[len - 1] == '"') name[len - 1] = 0;
    }
    strncpy(smpte_buf, smpte, sizeof(smpte_buf) - 1);
    smpte_buf[sizeof(smpte_buf) - 1] = 0;
    strncpy(name_buf, name, sizeof(name_buf) - 1);
    name_buf[sizeof(name_buf) - 1] = 0;
    trim(smpte_buf);
    trim(name_buf);
    if (first) {
      first = 0;
      if (strstr(smpte_buf, "SMPTE") || strstr(smpte_buf, "smpte") ||
          strstr(name_buf, "Marker") || strstr(name_buf, "marker")) {
        continue;
      }
    }
    if (!smpte_buf[0] || !name_buf[0]) continue;
    if (table->count >= MAX_MAPPINGS) break;
    {
      int absf = code_to_abs(smpte_buf, fps);
      if (absf < 0) {
        fprintf(log, "LOG\tInvalid SMPTE in CSV: %s\n", smpte_buf);
        continue;
      }
      table->items[table->count].abs_frames = absf;
      strncpy(table->items[table->count].name, name_buf, 255);
      table->items[table->count].name[255] = 0;
      table->count++;
    }
  }
  fclose(f);
  fprintf(log, "LOG\tLoaded %d mappings\n", table->count);
  return 0;
}

static const char *fuzzy_match(const MappingTable *table, int abs_frames, int tolerance) {
  int best_delta = tolerance + 1;
  const char *best = NULL;
  int i;
  for (i = 0; i < table->count; i++) {
    int d = abs_frames - table->items[i].abs_frames;
    if (d < 0) d = -d;
    if (d <= tolerance && d < best_delta) {
      best_delta = d;
      best = table->items[i].name;
    }
  }
  return best;
}

typedef struct {
  FILE *f;
  int sample_rate;
  int channels;
  int bits;
  int is_float;
  int bps;
  long data_offset;
  long frames_total;
} Wav;

static int read_u16(FILE *f) {
  unsigned char b[2];
  if (fread(b, 1, 2, f) != 2) return -1;
  return b[0] | (b[1] << 8);
}
static unsigned int read_u32(FILE *f) {
  unsigned char b[4];
  if (fread(b, 1, 4, f) != 4) return 0;
  return (unsigned)(b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24));
}

static int open_wav(const char *path, Wav *w, FILE *log) {
  char id[5] = {0};
  unsigned int size, fmt_size;
  int audio_format = 0;
  memset(w, 0, sizeof(*w));
  w->f = fopen(path, "rb");
  if (!w->f) {
    fprintf(log, "LOG\tCould not open audio: %s\n", path);
    return -1;
  }
  setvbuf(w->f, NULL, _IOFBF, 1 << 20); /* 1MB stdio buffer */

  if (fread(id, 1, 4, w->f) != 4 || strncmp(id, "RIFF", 4) != 0) {
    fprintf(log, "LOG\tNot a RIFF/WAV file (export/consolidate take to WAV if needed): %s\n", path);
    fclose(w->f);
    w->f = NULL;
    return -1;
  }
  read_u32(w->f);
  if (fread(id, 1, 4, w->f) != 4 || strncmp(id, "WAVE", 4) != 0) {
    fprintf(log, "LOG\tMissing WAVE chunk\n");
    fclose(w->f);
    w->f = NULL;
    return -1;
  }
  while (fread(id, 1, 4, w->f) == 4) {
    size = read_u32(w->f);
    if (strncmp(id, "fmt ", 4) == 0) {
      fmt_size = size;
      audio_format = read_u16(w->f);
      w->channels = read_u16(w->f);
      w->sample_rate = (int)read_u32(w->f);
      read_u32(w->f);
      read_u16(w->f);
      w->bits = read_u16(w->f);
      w->is_float = (audio_format == 3);
      if (fmt_size > 16) fseek(w->f, (long)fmt_size - 16, SEEK_CUR);
    } else if (strncmp(id, "data", 4) == 0) {
      w->data_offset = ftell(w->f);
      w->bps = w->is_float ? 4 : (w->bits / 8);
      w->frames_total = (long)size / (w->channels * w->bps);
      break;
    } else {
      fseek(w->f, (long)size, SEEK_CUR);
    }
  }
  if (!w->data_offset || !w->sample_rate || !w->channels) {
    fprintf(log, "LOG\tInvalid WAV fmt/data\n");
    fclose(w->f);
    w->f = NULL;
    return -1;
  }
  if (!(w->bits == 16 || w->bits == 24 || w->bits == 32 || w->is_float)) {
    fprintf(log, "LOG\tUnsupported WAV format (need PCM16/24/32 or float32)\n");
    fclose(w->f);
    w->f = NULL;
    return -1;
  }
  fprintf(log, "LOG\tWAV %d Hz, %d ch, %d-bit%s, %.2f sec\n",
          w->sample_rate, w->channels, w->bits, w->is_float ? " float" : "",
          (double)w->frames_total / (double)w->sample_rate);
  return 0;
}

/* Read mono floats at source rate.
 * Multi-channel: keep the sample with largest |amp| so LTC on right/other
 * channels still decodes (stereo SMPTE strips often put LTC on ch 2). */
static long read_mono_src(Wav *w, float *dst, long frames) {
  long i, n = 0;
  int ch = w->channels;
  for (i = 0; i < frames; i++) {
    float best = 0.f;
    float best_abs = -1.f;
    int c;
    for (c = 0; c < ch; c++) {
      float s = 0.f;
      float a;
      if (w->is_float || w->bits == 32) {
        float v;
        if (fread(&v, 4, 1, w->f) != 1) return n;
        s = v;
      } else if (w->bits == 16) {
        short v;
        if (fread(&v, 2, 1, w->f) != 1) return n;
        s = v / 32768.f;
      } else {
        unsigned char b[3];
        int v;
        if (fread(b, 1, 3, w->f) != 3) return n;
        v = b[0] | (b[1] << 8) | (b[2] << 16);
        if (v & 0x800000) v |= ~0xFFFFFF;
        s = v / 8388608.f;
      }
      a = s < 0.f ? -s : s;
      if (a > best_abs) {
        best_abs = a;
        best = s;
      }
    }
    dst[n++] = best;
  }
  return n;
}

/* Fast paths + linear downsample. Consumes all src_n frames. */
static long resample_to_decode_rate(const float *src, long src_n, int src_rate,
                                    float *dst, long dst_cap) {
  long out = 0;
  long i;
  if (src_n <= 0) return 0;

  if (src_rate == DECODE_RATE) {
    long n = src_n < dst_cap ? src_n : dst_cap;
    memcpy(dst, src, (size_t)n * sizeof(float));
    return n;
  }

  /* Exact integer decimation (96k→48k, 88.2k→44.1k-style when divisible) */
  if (src_rate % DECODE_RATE == 0) {
    int decim = src_rate / DECODE_RATE;
    long max_out = src_n / decim;
    if (max_out > dst_cap) max_out = dst_cap;
    for (i = 0; i < max_out; i++) {
      dst[i] = src[i * decim];
    }
    return max_out;
  }

  /* General: average windows (good enough for LTC square-ish signal) */
  {
    double acc = 0.0;
    double need = (double)src_rate / (double)DECODE_RATE;
    double have = 0.0;
    for (i = 0; i < src_n && out < dst_cap; i++) {
      acc += src[i];
      have += 1.0;
      if (have >= need) {
        dst[out++] = (float)(acc / have);
        acc = 0.0;
        have = 0.0;
      }
    }
  }
  return out;
}

int rlm_scan_file(const char *audio_path,
                  const char *mapping_csv_path,
                  const rlm_scan_options *opt,
                  FILE *out) {
  MappingTable table;
  Wav wav;
  LTCDecoder *decoder;
  rlm_scan_options o;
  float gain_lin;
  long src_chunk;
  float *src_buf = NULL;
  float *dec_buf = NULL;
  unsigned char *u8 = NULL;
  long frame_index = 0;
  double start_sec, end_sec;
  char last_name[256];
  double last_emit = -9999.0;
  int match_count = 0;
  int unmapped_unique = 0;
  int last_unmapped_abs = -999999;
  double last_progress_write = -9999.0;
  long frames_decoded = 0;
  double file_total_sec, scan_total;
  int auto_gain_left_chunks;
  int locked_auto = 0;
  float locked_gain = 1.f;

  if (!opt) return -1;
  o = *opt;
  if (o.fps <= 0) o.fps = 30;
  if (o.tolerance_frames <= 0) o.tolerance_frames = 3;

  if (load_mappings(mapping_csv_path, o.fps, &table, out) != 0) return -1;
  if (open_wav(audio_path, &wav, out) != 0) return -1;

  gain_lin = powf(10.f, o.gain_db / 20.f);
  src_chunk = (long)(wav.sample_rate * READ_SEC);
  if (src_chunk < 256) src_chunk = 256;

  src_buf = (float *)malloc((size_t)src_chunk * sizeof(float));
  dec_buf = (float *)malloc((size_t)(DECODE_RATE * READ_SEC + 64) * sizeof(float));
  u8 = (unsigned char *)malloc((size_t)(DECODE_RATE * READ_SEC + 64));
  if (!src_buf || !dec_buf || !u8) {
    free(src_buf);
    free(dec_buf);
    free(u8);
    fclose(wav.f);
    return -1;
  }

  decoder = ltc_decoder_create(DECODE_RATE / o.fps, o.fps * 80);
  if (!decoder) {
    fprintf(out, "LOG\tltc_decoder_create failed\n");
    free(src_buf);
    free(dec_buf);
    free(u8);
    fclose(wav.f);
    return -1;
  }

  start_sec = o.start_sec > 0 ? o.start_sec : 0;
  end_sec = (o.length_sec > 0) ? (start_sec + o.length_sec) : 1e18;
  {
    long start_frame = (long)(start_sec * wav.sample_rate);
    if (start_frame > 0) {
      fseek(wav.f, wav.data_offset + start_frame * wav.channels * wav.bps, SEEK_SET);
      frame_index = start_frame;
    } else {
      fseek(wav.f, wav.data_offset, SEEK_SET);
    }
  }

  file_total_sec = (double)wav.frames_total / (double)wav.sample_rate;
  scan_total = (end_sec >= 1e17) ? (file_total_sec - start_sec) : (end_sec - start_sec);
  if (scan_total < 0.001) scan_total = file_total_sec;

  fprintf(out, "LOG\tDecode @ %d Hz (source %d Hz)%s\n",
          DECODE_RATE, wav.sample_rate,
          wav.sample_rate == DECODE_RATE ? "" : " — downsampled for speed");
  fprintf(out, "LOG\tScanning %.2f sec starting at %.2f (file %.2f sec)\n",
          scan_total, start_sec, file_total_sec);
  write_progress(o.progress_path, 0.0, scan_total, 0);

  last_name[0] = 0;
  /* Apply auto-gain only for the first ~2 seconds, then lock — matches quiet-LTC fix without per-chunk cost forever */
  auto_gain_left_chunks = o.auto_gain ? (int)(2.0 / READ_SEC) + 1 : 0;

  while (1) {
    double t0 = (double)frame_index / (double)wav.sample_rate;
    long got_src, got_dec;
    size_t i;
    LTCFrameExt frame;
    float peak = 0.f;
    float chunk_gain = gain_lin * locked_gain;

    if (t0 >= end_sec) break;
    got_src = read_mono_src(&wav, src_buf, src_chunk);
    if (got_src <= 0) break;

    if (auto_gain_left_chunks > 0) {
      for (i = 0; i < (size_t)got_src; i++) {
        float a = src_buf[i] < 0 ? -src_buf[i] : src_buf[i];
        if (a > peak) peak = a;
      }
      if (peak > 0.f && peak < 0.2f) {
        locked_gain = 1.f / peak;
        locked_auto = 1;
        chunk_gain = gain_lin * locked_gain;
      }
      auto_gain_left_chunks--;
      if (auto_gain_left_chunks == 0 && locked_auto) {
        fprintf(out, "LOG\tAuto-gain locked at x%.2f\n", locked_gain);
      }
    }

    for (i = 0; i < (size_t)got_src; i++) {
      src_buf[i] *= chunk_gain;
    }

    got_dec = resample_to_decode_rate(src_buf, got_src, wav.sample_rate,
                                      dec_buf, (long)(DECODE_RATE * READ_SEC + 64));

    for (i = 0; i < (size_t)got_dec; i++) {
      float s = dec_buf[i];
      if (s < -1.f) s = -1.f;
      if (s > 1.f) s = 1.f;
      u8[i] = (unsigned char)((s + 1.f) * 127.5f);
    }

    /* posinfo in decode-rate samples mapped from source file position */
    {
      ltc_off_t posinfo = (ltc_off_t)((double)frame_index * (double)DECODE_RATE / (double)wav.sample_rate);
      ltc_decoder_write(decoder, u8, (size_t)got_dec, posinfo);
    }

    while (ltc_decoder_read(decoder, &frame)) {
      int hours = frame.ltc.hours_units + frame.ltc.hours_tens * 10;
      int mins = frame.ltc.mins_units + frame.ltc.mins_tens * 10;
      int secs = frame.ltc.secs_units + frame.ltc.secs_tens * 10;
      int fr = frame.ltc.frame_units + frame.ltc.frame_tens * 10;
      char tc[32];
      int absf;
      const char *match;
      /* Convert decode-rate offset back to source file seconds */
      double pos_sec = (double)frame.off_start / (double)DECODE_RATE;

      frames_decoded++;
      format_tc(hours, mins, secs, fr, tc, sizeof(tc));
      absf = code_to_abs(tc, o.fps);
      match = fuzzy_match(&table, absf, o.tolerance_frames);
      if (match) {
        if (!(strcmp(match, last_name) == 0 && (pos_sec - last_emit) < MIN_GAP_SEC)) {
          fprintf(out, "MATCH\t%.6f\t%s\t%s\n", pos_sec, match, tc);
          fflush(out);
          strncpy(last_name, match, sizeof(last_name) - 1);
          last_name[sizeof(last_name) - 1] = 0;
          last_emit = pos_sec;
          match_count++;
        }
      } else if (absf != last_unmapped_abs) {
        last_unmapped_abs = absf;
        if (unmapped_unique < 64) {
          fprintf(out, "UNMAPPED\t%.6f\t%s\n", pos_sec, tc);
          unmapped_unique++;
        }
      }
    }

    frame_index += got_src;

    {
      double scanned = ((double)frame_index / (double)wav.sample_rate) - start_sec;
      if (scanned - last_progress_write >= PROGRESS_EVERY_SEC) {
        write_progress(o.progress_path, scanned < 0 ? 0 : scanned, scan_total, match_count);
        last_progress_write = scanned;
      }
    }
  }

  write_progress(o.progress_path, scan_total, scan_total, match_count);
  fprintf(out, "LOG\tScan complete: %d matches, %ld LTC frames seen, %d unique unmapped (capped)\n",
          match_count, frames_decoded, unmapped_unique);
  fflush(out);

  ltc_decoder_free(decoder);
  free(src_buf);
  free(dec_buf);
  free(u8);
  fclose(wav.f);
  return 0;
}
