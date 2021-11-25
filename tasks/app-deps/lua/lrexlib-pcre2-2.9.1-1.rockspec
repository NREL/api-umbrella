build = {
  type = "builtin",
  modules = {
    rex_pcre2 = {
      defines = {
        "VERSION=\"2.9.1\"",
        "PCRE2_CODE_UNIT_WIDTH=8",
      },
      sources = {
        "src/common.c",
        "src/pcre2/lpcre2.c",
        "src/pcre2/lpcre2_f.c",
      },
      libraries = {
        "pcre2-8",
        -- API Umbrella build customization: Include luajit.
        "luajit-5.1",
      },
      incdirs = {
        "$(PCRE2_INCDIR)",
      },
      libdirs = {
        "$(PCRE2_LIBDIR)",
        -- API Umbrella build customization: Include libdir.
        "$(STAGE_EMBEDDED_LIBDIR)",
      },
    },
  },
}
external_dependencies = {
  PCRE2 = {
    header = "pcre2.h",
    library = "pcre2-8",
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
This rock provides the PCRE2 bindings.",
  summary = "Regular expression library binding (PCRE2 flavour).",
}
version = "2.9.1-1"
package = "Lrexlib-PCRE2"
