# A12E Scale Monitor - ESP-IDF production build (Secure Boot v2 pilot)
#
# The application sources still live in ../src so the PlatformIO build on
# main keeps working. This component only wires them into ESP-IDF.

idf_component_register(
    SRCS
        "../src/main.cpp"
        "../src/license.cpp"
        "../src/log.cpp"
        "../src/net.cpp"
        "../src/settings.cpp"
        "../src/sheets.cpp"
    INCLUDE_DIRS
        "../include"
    REQUIRES
        arduino
        app_update
)
