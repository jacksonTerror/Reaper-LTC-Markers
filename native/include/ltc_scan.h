#ifndef RLM_LTC_SCAN_H
#define RLM_LTC_SCAN_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  int fps;              /* e.g. 24, 25, 30 */
  int tolerance_frames; /* fuzzy match window */
  float gain_db;        /* manual / floor gain */
  int auto_gain;        /* 1 = normalize quiet chunks */
  double start_sec;     /* skip this many seconds into file (take offset) */
  double length_sec;    /* 0 = to EOF */
  const char *progress_path; /* optional; overwritten with live PROGRESS lines */
} rlm_scan_options;

/*
 * Scan audio_path with mapping CSV.
 * Writes protocol lines to out (FILE*):
 *   MATCH\tpos_sec\tname\ttimecode
 *   UNMAPPED\tpos_sec\ttimecode
 *   LOG\tmessage
 * Returns 0 on success.
 */
int rlm_scan_file(const char *audio_path,
                  const char *mapping_csv_path,
                  const rlm_scan_options *opt,
                  FILE *out);

#ifdef __cplusplus
}
#endif

#endif
