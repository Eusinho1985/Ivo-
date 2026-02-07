macro(Ivo__configure_linker project_name)
  set(Ivo__USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(Ivo__USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE Ivo__USER_LINKER_OPTION PROPERTY STRINGS ${Ivo__USER_LINKER_OPTION_VALUES})
  list(
    FIND
    Ivo__USER_LINKER_OPTION_VALUES
    ${Ivo__USER_LINKER_OPTION}
    Ivo__USER_LINKER_OPTION_INDEX)

  if(${Ivo__USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${Ivo__USER_LINKER_OPTION}', explicitly supported entries are ${Ivo__USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${Ivo__USER_LINKER_OPTION}")
endmacro()
