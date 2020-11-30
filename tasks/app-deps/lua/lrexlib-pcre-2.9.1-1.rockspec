build = {
  type = "builtin",
  modules = {
    rex_pcre = {
      defines = {
        "VERSION=\"2.9.1\"",
        "PCRE2_CODE_UNIT_WIDTH=8",
      },
      sources = {
        "src/common.c",
        "src/pcre/lpcre.c",
        "src/pcre/lpcre_f.c",
      },
      libraries = {
        "pcre",
        "luajit-5.1",
      },
      incdirs = {
        "$(PCRE_INCDIR)",
      },
      libdirs = {
        "$(PCRE_LIBDIR)",
        "$(STAGE_EMBEDDED_LIBDIR)",
      },
    },
  },
}
external_dependencies = {
  PCRE = {
    header = "pcre.h",
    library = "pcre",
  },
}
dependencies = {
  "lua >= 5.1",
}
source = {
  tag = "rel-2-9-1",
  url = "git://github.com/rrthomas/lrexlib.git",
}
description = {
  homepage = "http://github.com/rrthomas/lrexlib",
  license = "MIT/X11",
  detailed = "Lrexlib is a regular expression library for Lua 5.1-5.4, which\
provides bindings for several regular expression libraries.\
This rock provides the PCRE bindings.",
  summary = "Regular expression library binding (PCRE flavour).",
}
version = "2.9.1-1"
package = "Lrexlib-PCRE"
