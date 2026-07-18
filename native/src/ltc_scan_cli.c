#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ltc_scan.h"

static void usage(const char *argv0) {
  fprintf(stderr,
          "Usage: %s --audio FILE --mapping CSV [options]\n"
          "  --fps N            Frame rate (default 30)\n"
          "  --tolerance N      Fuzzy match frames (default 3)\n"
          "  --gain-db N        Apply gain in dB (default 0)\n"
          "  --auto-gain        Normalize quiet chunks (peak < -14 dBFS)\n"
          "  --start-sec N      Start offset in audio file\n"
          "  --length-sec N     Length to scan (0 = rest of file)\n"
          "  --out FILE         Write results to FILE (recommended)\n"
          "  --progress FILE    Live progress for UI polling\n"
          "  --done FILE        Written when scan finishes (exit code)\n",
          argv0);
}

static void write_done(const char *path, int rc) {
  FILE *df;
  if (!path || !path[0]) return;
  df = fopen(path, "w");
  if (!df) return;
  fprintf(df, "%d\n", rc);
  fclose(df);
}

int main(int argc, char **argv) {
  const char *audio = NULL;
  const char *mapping = NULL;
  const char *out_path = NULL;
  const char *progress_path = NULL;
  const char *done_path = NULL;
  rlm_scan_options opt;
  FILE *out;
  int i, rc;

  memset(&opt, 0, sizeof(opt));
  opt.fps = 30;
  opt.tolerance_frames = 3;
  opt.gain_db = 0.f;
  opt.auto_gain = 0;
  opt.start_sec = 0;
  opt.length_sec = 0;
  opt.progress_path = NULL;

  for (i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "--audio") && i + 1 < argc) {
      audio = argv[++i];
    } else if (!strcmp(argv[i], "--mapping") && i + 1 < argc) {
      mapping = argv[++i];
    } else if (!strcmp(argv[i], "--fps") && i + 1 < argc) {
      opt.fps = atoi(argv[++i]);
      if (opt.fps <= 0) opt.fps = 30;
    } else if (!strcmp(argv[i], "--tolerance") && i + 1 < argc) {
      opt.tolerance_frames = atoi(argv[++i]);
    } else if (!strcmp(argv[i], "--gain-db") && i + 1 < argc) {
      opt.gain_db = (float)atof(argv[++i]);
    } else if (!strcmp(argv[i], "--auto-gain")) {
      opt.auto_gain = 1;
    } else if (!strcmp(argv[i], "--start-sec") && i + 1 < argc) {
      opt.start_sec = atof(argv[++i]);
    } else if (!strcmp(argv[i], "--length-sec") && i + 1 < argc) {
      opt.length_sec = atof(argv[++i]);
    } else if (!strcmp(argv[i], "--out") && i + 1 < argc) {
      out_path = argv[++i];
    } else if (!strcmp(argv[i], "--progress") && i + 1 < argc) {
      progress_path = argv[++i];
    } else if (!strcmp(argv[i], "--done") && i + 1 < argc) {
      done_path = argv[++i];
    } else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
      usage(argv[0]);
      return 0;
    } else {
      fprintf(stderr, "Unknown arg: %s\n", argv[i]);
      usage(argv[0]);
      return 2;
    }
  }

  if (!audio || !mapping) {
    usage(argv[0]);
    write_done(done_path, 2);
    return 2;
  }

  opt.progress_path = progress_path;

  if (out_path) {
    out = fopen(out_path, "w");
    if (!out) {
      write_done(done_path, 1);
      return 1;
    }
  } else {
    out = stdout;
    setvbuf(stdout, NULL, _IONBF, 0);
  }

  rc = rlm_scan_file(audio, mapping, &opt, out);
  if (out_path) {
    fclose(out);
  }
  write_done(done_path, rc == 0 ? 0 : 1);
  return rc == 0 ? 0 : 1;
}
