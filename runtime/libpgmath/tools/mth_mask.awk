#
# Copyright (c) 2017-2018, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

function print_hdrs()
{
  print "\
/*\n\
 *     Copyright (c) 2018, NVIDIA CORPORATION.  All rights reserved.\n\
 *\n\
 * NVIDIA CORPORATION and its licensors retain all intellectual property\n\
 * and proprietary rights in and to this software, related documentation\n\
 * and any modifications thereto.  Any use, reproduction, disclosure or\n\
 * distribution of this software and related documentation without an express\n\
 * license agreement from NVIDIA CORPORATION is strictly prohibited.\n\
 *\n\
 */\n\
\n\n\
#include \"mth_intrinsics.h\" \n\
#include \"mth_tbldefs.h\" \n\
\n\n\
static const vrs4_t Csp1_4={1.0, 1.0, 1.0, 1.0}; \n\
static const vrd2_t Cdp1_2={1.0, 1.0}; \n\
static const vrs8_t Csp1_8={1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}; \n\
static const vrd4_t Cdp1_4={1.0, 1.0, 1.0, 1.0}; \n\
static const vrs16_t Csp1_16={1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, \n\
                             1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}; \n\
static const vrd8_t Cdp1_8={1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}; \n\
\n\n\
#if defined (TARGET_X8664) \n\
#include \"immintrin.h\" \n\
#elif defined (TARGET_LINUX_POWER) \n\
#include \"altivec.h\" \n\
#else \n\
#error Unknown TARGET. Must be either \"TARGET_X8664\" or \"TARGET_LINUX_POWER\" \n\
#endif \n\
\n\
#if defined(TARGET_OSX_X8664)\n\
#warning All AVX512F routines are dummy!\n\
#warning Routines had to be dummied out because clang assembler does not\n\
#warning support vpternlogd and 512-bit version of square root\n\
#warning vpternlogd generated by _mm512_set1_epi32(-1) instruction.\n\
#warning All 512-bit mask interface routines for OSX will abort.\n\
#include <assert.h>\n\
#endif\n\
"
}

function init_target_arrays()
{
  if (TARGET == "POWER") {
    divsd["fs"] = "vec_div(x, y)"
    divsd["fd"] = "vec_div(x, y)"
    divsd["rs"] = "vec_div(x, y)"
    divsd["rd"] = "vec_div(x, y)"
    # For some unexplained reason, the native and llvm compilers implements 
    # relaxed divide on POWER using reciprocal and a multiply.
    divsd["rs"] = "vec_mul(x, vec_div(Csp1_" VL("s") ", y))"
    divsd["rd"] = "vec_mul(x, vec_div(Cdp1_" VL("d") ", y))"
    divsd["ps"] = "vec_div(x, y)"
    divsd["pd"] = "vec_div(x, y)"

    sqrtsd["fs"] = "vec_sqrt(x)"
    sqrtsd["fd"] = "vec_sqrt(x)"
    sqrtsd["rs"] = "vec_sqrt(x)"
    sqrtsd["rd"] = "vec_sqrt(x)"
    sqrtsd["ps"] = "vec_sqrt(x)"
    sqrtsd["pd"] = "vec_sqrt(x)"
    mask_all_zero = "(vec_all_eq(mask, vec_xor(mask,mask)) == 1)"
  } else {
    if (VLS == 4) {
      _mm = "_mm"
      __m = "__m128"
      _si = "_si128"
    } else if (VLS == 8) {
      _mm = "_mm256"
      __m = "__m256"
      _si = "_si256"
    } else {
      _mm = "_mm512"
      __m = "__m512"
      _si = "_si512"
    }
   
    divsd["fs"] = _mm "_div_ps((" __m ")x, (" __m ")y)"
    divsd["fd"] = _mm "_div_pd((" __m "d)x, (" __m "d)y)"
    divsd["rs"] = _mm "_div_ps((" __m ")x, (" __m ")y)"
    divsd["rd"] = _mm "_div_pd((" __m "d)x, (" __m "d)y)"
    # For some unexplained reason, the native and llvm compilers implements 
    # relaxed divide on X86-64 using reciprocal and a multiply.
    divsd["rs"] = _mm "_mul_ps((" __m ")x, " _mm "_div_ps(Csp1_" VL("s") ", ( " __m ")y))"
    divsd["rd"] = _mm "_mul_pd((" __m "d)x, " _mm "_div_pd(Cdp1_" VL("d") ", ( " __m "d)y))"
    divsd["ps"] = _mm "_div_ps((" __m ")x, (" __m ")y)"
    divsd["pd"] = _mm "_div_pd((" __m "d)x, (" __m "d)y)"

    sqrtsd["fs"] = _mm "_sqrt_ps((" __m ")x)"
    sqrtsd["fd"] = _mm "_sqrt_pd((" __m "d)x)"
    sqrtsd["rs"] = _mm "_sqrt_ps((" __m ")x)"
    sqrtsd["rd"] = _mm "_sqrt_pd((" __m "d)x)"
    sqrtsd["ps"] = _mm "_sqrt_ps((" __m ")x)"
    sqrtsd["pd"] = _mm "_sqrt_pd((" __m "d)x)"

    # For vector register size == 128, it would be faster to use the
    # (_mm_testz_si128((__m128i)mask, _mm_set1_epi32(-1) == 1), but we
    # compile mth_128mask.c for core2 processors (gcc -march=core2),
    # and the ptest instruction (_mm_testz_si128()) is not available
    # until SSE4.1.

#    mask_all_zero =  (VLS == 4) ? \
#       "(_mm_movemask_ps((__m128) _mm_cmpeq_epi32((__m128i)mask, \
#                      _mm_xor_si128((__m128i)mask,(__m128i)mask))) == 15)" : \
#      "(_mm256_testz_si256((__m256i)mask, _mm256_set1_epi32(-1)) == 1)"
    if (VLS == 4) {
      mask_all_zero = \
        "(_mm_movemask_ps((__m128) _mm_cmpeq_epi32((__m128i)mask, " \
        "_mm_xor_si128((__m128i)mask,(__m128i)mask))) == 15)"
    } else if (VLS == 8) {
      mask_all_zero = \
        "(_mm256_testz_si256((__m256i)mask, _mm256_set1_epi32(-1)) == 1)"
    } else {
      mask_all_zero = \
        "(_mm512_test_epi32_mask((__m512i)mask, _mm512_set1_epi32(-1)) == 0)"
    }
  }

  frps["f"]= ""
  frps["r"]= ""
  frps["p"]= ""
  sds["s"]= ""
  sds["d"]= ""
  iks["i"]= ""
  iks["k"]= ""
}

function VL(sd)
{
  return sd == "s" ? VLS : VLD
}

function VR_T(sd) {
  return "vr" sd (sd == "s" ? VLS : VLD) "_t"
}

function VI_T(sd) {
  return "vi" sd (sd == "s" ? VLS : VLD) "_t"
}

function arg_ne_0(yarg, a, b)
{
  return yarg != 0 ? a : b
}

function func_r_decl(name, frp, sd, yarg)
{
  print "\n" VR_T(sd)
  print "__" frp sd "_" name "_" VL(sd) "_mn" \
        "(" VR_T(sd) " x" \
        arg_ne_0(yarg, ", " VR_T(sd) " y",  "") \
        ", " VI_T(sd) " mask)"
        
}

function func_rr_def(name, frp, sd, safeval, yarg) {
  func_r_decl(name, frp, sd, yarg)
  print "{"
  if (VLS == 16) {
    print "#if !defined(TARGET_OSX_X8664)"
  }
  print "  " \
        VR_T(sd) " (*fptr) (" VR_T(sd) \
        arg_ne_0(yarg, ", " VR_T(sd), "") \
        ");"
  # X86-64 tests assume input vector is return if mask is all zero.
  # print "  if(" mask_all_zero ") return (" VR_T(sd) ")mask;"
  print "  if(" mask_all_zero ") return x;"
  print "  x = (" VR_T(sd) ")((((" VI_T(sd) ")x & mask))" \
        arg_ne_0(safeval, " | ((" VI_T(sd) ")C" sd "p1_" VL(sd) " & ~mask)", "") \
        ");"
  if (yarg != 0) {
    print "  y = (" VR_T(sd) ")((((" VI_T(sd) ")y & mask))" \
        arg_ne_0(safeval, " | ((" VI_T(sd) ")C" sd "p1_" VL(sd) " & ~mask)", "") \
        ");"
  }
  if (name != "div" && name != "sqrt") {
    print "  fptr = (" VR_T(sd) "(*) (" VR_T(sd), \
          (yarg != 0) ? ", " VR_T(sd) : "", \
          ")) MTH_DISPATCH_TBL[func_" name "][sv_" sd "v" VL(sd) "][frp_" frp "];"
    print "  return (fptr(x", (yarg != 0) ? ", y" : "", "));"
  } else {
    print "  return (", (name == "div") ? divsd[frp sd] : sqrtsd[frp sd], ");"
  }
  if (VLS == 16) {
    print "#else	// #if !defined(TARGET_OSX_X8664"
    print "  assert(0);"
    print "  return (" VR_T(sd) ") _mm512_set1_epi32(0);"
    print "#endif	// #if !defined(TARGET_OSX_X8664"
  }
    print "}"
}

function func_pow_args_nomask(sd, is_scalar, ik, with_vars)
{
  ll = VR_T(sd) arg_ne_0(with_vars, " x", "") ", "
  if (is_scalar) {
    ll = ll ((ik == "i") ? "int32_t" : "int64_t") arg_ne_0(with_vars, " iy", "")
  } else {
    if (sd == "s" && ik == "k") {
      ll = ll VI_T("d") arg_ne_0(with_vars, " iyu", "") ", " \
            VI_T("d") arg_ne_0(with_vars, " iyl", "")
    } else {
      ll = ll VI_T(ik == "i" ? "s" : "d") arg_ne_0(with_vars, " iy", "")
    }
  }

  return ll
}

function func_pow_decl(name, frp, sd, is_scalar, ik)
{
  print "\n" VR_T(sd)
  l = "__" frp sd "_" name arg_ne_0(is_scalar, ik"1", ik)"_" VL(sd) "_mn" "("
  l = l func_pow_args_nomask(sd, is_scalar, ik, 1)
  l = l ", " VI_T(sd) " mask)"
  print l
        
}

function func_pow_def(name, frp, sd, is_scalar, ik)
{
  func_pow_decl(name, frp, sd, is_scalar, ik)
  print "{"
  if (VLS == 16) {
    print "#if !defined(TARGET_OSX_X8664)"
  }
  print "  "\
        VR_T(sd) " (*fptr) (" func_pow_args_nomask(sd, is_scalar, ik, 0) ");"
  # X86-64 tests assume input vector is return if mask is all zero.
  # print "  if(" mask_all_zero ") return (" VR_T(sd) ")mask;"
  print "  if(" mask_all_zero ") return x;"
  print "  x = ("VR_T(sd) ")((" VI_T(sd) ")x & mask);"
  if (is_scalar == 0) {
    if((sd == "s" && ik == "i") || (sd == "d" && ik == "k")) {
      print "  iy = iy & mask;"
    } else {
      print "  {\n"\
            "    int i;\n"\
            "    for (i = 0 ; i < " VL(sd) "; i++) {\n"\
            "      if (mask[i] == 0) {"
      if (sd == "s") {
        print "        if(i < " VL(d) ") {\n"\
              "          iyu[i] = 0;\n"\
              "        } else {\n"\
              "          iyl[i-" VL(d) "] = 0;\n"\
              "        }"
      } else {
        print "        iy[i] = 0;"\
      }
      print "      }\n    }\n  }"
    }
  }
  print "  fptr = (" VR_T(sd) "(*) (" \
        func_pow_args_nomask(sd, is_scalar, ik, 0) \
        ")) MTH_DISPATCH_TBL[func_" name arg_ne_0(is_scalar, ik"1", ik) \
        "][sv_" sd "v" VL(sd) "][frp_" frp "];"
  print "  return (fptr(x, ", \
        arg_ne_0(is_scalar == 0 && sd == "s" && ik == "k", "iyu, iyl", "iy") \
        "));"
  if (VLS == 16) {
    print "#else	// #if !defined(TARGET_OSX_X8664"
    print "  assert(0);"
    print "  return (" VR_T(sd) ") _mm512_set1_epi32(0);"
    print "#endif	// #if !defined(TARGET_OSX_X8664"
  }
  print "}"
}

function do_all_rr(name, safeval, yarg)
{

  for (frp in frps) {
    for (sd in sds) {
      func_rr_def(name, frp, sd, safeval, yarg)
    }
  }
}

function do_all_pow_r2i()
{
  for (frp in frps) {
    for (sd in sds) {
      for (ik in iks) {
        func_pow_def("pow", frp, sd, 1, ik)
        func_pow_def("pow", frp, sd, 0, ik)
      }
    }
  }
}

BEGIN {
  if (TARGET != "POWER" && TARGET != "X8664") {
    print "TARGET must be one of POWER or X8664"
    exit(1)
  }
  if (TARGET == "POWER") {
    if (MAX_VREG_SIZE != 128) {
      print "TARGET == POWER, MAX_VREG_SIZE must be 128"
      exit(1)
    }
  } else if (MAX_VREG_SIZE != 128 && MAX_VREG_SIZE != 256 && MAX_VREG_SIZE != 512) {
    print "TARGET == X8664, MAX_VREG_SIZE must be either 128, 256, or 512"
    exit(1)
  }

  if (MAX_VREG_SIZE == 128) {
    VLS = 4
    VLD = 2
  } else if (MAX_VREG_SIZE == 256) {
    VLS = 8
    VLD = 4
  } else {
    VLS = 16
    VLD = 8
  }

# Initialize some associative arrays
  init_target_arrays()

  print_hdrs()
  one_arg = 0
  two_args = 1


  do_all_rr("acos", 0, one_arg)
  do_all_rr("asin", 0, one_arg)
  do_all_rr("atan", 0, one_arg)
  do_all_rr("atan2", 1, two_args)
  do_all_rr("cos", 0, one_arg)
  do_all_rr("sin", 0, one_arg)
  do_all_rr("tan", 0, one_arg)
  do_all_rr("sincos", 0, one_arg)
  do_all_rr("cosh", 0, one_arg)
  do_all_rr("sinh", 0, one_arg)
  do_all_rr("tanh", 0, one_arg)
  do_all_rr("exp", 0, one_arg)
  do_all_rr("log", 1, one_arg)
  do_all_rr("log10", 1, one_arg)
  do_all_rr("pow", 0, two_args)
  do_all_rr("div", 1, two_args)
  do_all_rr("sqrt", 0, one_arg)
  do_all_rr("mod", 1, two_args)

  do_all_pow_r2i()
}