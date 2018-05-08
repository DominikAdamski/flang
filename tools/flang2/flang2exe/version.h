/*
 * Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#ifndef VERSION_H_
#define VERSION_H_

typedef struct {
  char *lang;    /* language */
  char *host;    /* host */
  char *vsn;     /* version number */
  char *bld;     /* build number */
  char *dvsn;    /* date-based version number */
  char *target;  /* target compiler */
  char *product; /* product designation */
  char *copyright;
} VERSION;

extern VERSION version;

/**
   \brief ...
 */
char *get_version_string(void);


#endif // VERSION_H_
