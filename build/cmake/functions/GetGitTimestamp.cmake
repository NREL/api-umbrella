function(get_git_timestamp _var)
  if(NOT GIT_FOUND)
    find_package(Git QUIET)
  endif()
  get_git_head_revision(refspec hash)
  if(NOT GIT_FOUND)
    set(${_var} "GIT-NOTFOUND" PARENT_SCOPE)
    return()
  endif()

  execute_process(COMMAND
    git log --max-count=1 --date=iso --format=%cd ${hash}
    WORKING_DIRECTORY
    "${CMAKE_CURRENT_SOURCE_DIR}"
    RESULT_VARIABLE
    res
    OUTPUT_VARIABLE
    out
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT res EQUAL 0)
    set(out "${out}-${res}-NOTFOUND")
  endif()

  execute_process(COMMAND
    date -d ${out} -u +%Y%m%d%H%M%S
    WORKING_DIRECTORY
    "${CMAKE_CURRENT_SOURCE_DIR}"
    RESULT_VARIABLE
    res
    OUTPUT_VARIABLE
    out
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT res EQUAL 0)
    set(out "${out}-${res}-NOTFOUND")
  endif()

  set(${_var} "${out}" PARENT_SCOPE)
endfunction()
