cmake_minimum_required(VERSION 3.10)
project(launcher Java)
find_package(Java 1.7 REQUIRED COMPONENTS Development)

include(UseJava)
set(CMAKE_JAVA_JAR_ENTRY_POINT org.berserkmc.EntryPoint)
set(CMAKE_JAVA_COMPILE_FLAGS -target 8 -source 8 -Xlint:deprecation -Xlint:unchecked)

set(SRC
    org/berserkmc/EntryPoint.java
    org/berserkmc/Launcher.java
    org/berserkmc/LegacyFrame.java
    org/berserkmc/NotFoundException.java
    org/berserkmc/ParamBucket.java
    org/berserkmc/ParseException.java
    org/berserkmc/Utils.java
    org/berserkmc/onesix/OneSixLauncher.java
    net/minecraft/Launcher.java
)
add_jar(NewLaunch ${SRC})
install_jar(NewLaunch "${JARS_DEST_DIR}")
