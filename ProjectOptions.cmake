include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(Ivo__supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(Ivo__setup_options)
  option(Ivo__ENABLE_HARDENING "Enable hardening" ON)
  option(Ivo__ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Ivo__ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Ivo__ENABLE_HARDENING
    OFF)

  Ivo__supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Ivo__PACKAGING_MAINTAINER_MODE)
    option(Ivo__ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Ivo__WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Ivo__ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Ivo__ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Ivo__ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Ivo__ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Ivo__ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Ivo__ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Ivo__ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Ivo__ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Ivo__ENABLE_PCH "Enable precompiled headers" OFF)
    option(Ivo__ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Ivo__ENABLE_IPO "Enable IPO/LTO" ON)
    option(Ivo__WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Ivo__ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Ivo__ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Ivo__ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Ivo__ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Ivo__ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Ivo__ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Ivo__ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Ivo__ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Ivo__ENABLE_PCH "Enable precompiled headers" OFF)
    option(Ivo__ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Ivo__ENABLE_IPO
      Ivo__WARNINGS_AS_ERRORS
      Ivo__ENABLE_SANITIZER_ADDRESS
      Ivo__ENABLE_SANITIZER_LEAK
      Ivo__ENABLE_SANITIZER_UNDEFINED
      Ivo__ENABLE_SANITIZER_THREAD
      Ivo__ENABLE_SANITIZER_MEMORY
      Ivo__ENABLE_UNITY_BUILD
      Ivo__ENABLE_CLANG_TIDY
      Ivo__ENABLE_CPPCHECK
      Ivo__ENABLE_COVERAGE
      Ivo__ENABLE_PCH
      Ivo__ENABLE_CACHE)
  endif()

  Ivo__check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Ivo__ENABLE_SANITIZER_ADDRESS OR Ivo__ENABLE_SANITIZER_THREAD OR Ivo__ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Ivo__BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Ivo__global_options)
  if(Ivo__ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Ivo__enable_ipo()
  endif()

  Ivo__supports_sanitizers()

  if(Ivo__ENABLE_HARDENING AND Ivo__ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Ivo__ENABLE_SANITIZER_UNDEFINED
       OR Ivo__ENABLE_SANITIZER_ADDRESS
       OR Ivo__ENABLE_SANITIZER_THREAD
       OR Ivo__ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Ivo__ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Ivo__ENABLE_SANITIZER_UNDEFINED}")
    Ivo__enable_hardening(Ivo__options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Ivo__local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Ivo__warnings INTERFACE)
  add_library(Ivo__options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Ivo__set_project_warnings(
    Ivo__warnings
    ${Ivo__WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    Ivo__enable_sanitizers(
      Ivo__options
      ${Ivo__ENABLE_SANITIZER_ADDRESS}
      ${Ivo__ENABLE_SANITIZER_LEAK}
      ${Ivo__ENABLE_SANITIZER_UNDEFINED}
      ${Ivo__ENABLE_SANITIZER_THREAD}
      ${Ivo__ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(Ivo__options PROPERTIES UNITY_BUILD ${Ivo__ENABLE_UNITY_BUILD})

  if(Ivo__ENABLE_PCH)
    target_precompile_headers(
      Ivo__options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Ivo__ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Ivo__enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Ivo__ENABLE_CLANG_TIDY)
    Ivo__enable_clang_tidy(Ivo__options ${Ivo__WARNINGS_AS_ERRORS})
  endif()

  if(Ivo__ENABLE_CPPCHECK)
    Ivo__enable_cppcheck(${Ivo__WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Ivo__ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Ivo__enable_coverage(Ivo__options)
  endif()

  if(Ivo__WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Ivo__options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Ivo__ENABLE_HARDENING AND NOT Ivo__ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Ivo__ENABLE_SANITIZER_UNDEFINED
       OR Ivo__ENABLE_SANITIZER_ADDRESS
       OR Ivo__ENABLE_SANITIZER_THREAD
       OR Ivo__ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Ivo__enable_hardening(Ivo__options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
