#!/bin/sh
# Bash script that can analyze a Spring Boot application using jdeps and use the output to create a custom JRE runtime using jlink.
# Note that it designed specifically for Spring Boot types, will not work for simple java applications or other frameworks.

# Example usage:
# ./create-minimal-jre.sh build/libs/*.jar 17 minimal-jre

# The set options used here are:
# -e	Instructs a shell to exit if a command fails, i.e., if it outputs a non-zero exit status.
# -u    Treats unset or undefined variables as an error when substituting (during parameter expansion). Does not apply to special parameters such as wildcard * or @.
set -eu

#Target jar application to run jdeps over.
readonly TARGET_JAR=$1
#Target java version to use as the value for the flag --multi-release of jdeps.
readonly TARGET_VER=$2
#Target folder to put the custom runtime into.
readonly TARGET_FOLDER=$3

#Empty target directory to make sure it contains nothing except the output from jlink.
echo Deleting target folder: ${TARGET_FOLDER}...
rm -rf ${TARGET_FOLDER}

#Temporary directory to extract the jar
readonly TMP_DIR="tmp"

#Clean temporary directory prior to creating it.
rm -rf ${TMP_DIR}; mkdir ${TMP_DIR}

#Automatically remove the TMP_DIR when the script exits.
trap 'rm -rf ${TMP_DIR}' EXIT

echo Unzipping jar into temporary directory...
#Unzip the jar into the temporary directory.
unzip -q "${TARGET_JAR}" -d "${TMP_DIR}"

echo Running jdeps over project...
#Run jdeps over all deps.

jdeps \
    --class-path "tmp/BOOT-INF/classes:tmp/BOOT-INF/lib:tmp/org" \
    --print-module-deps \
    --ignore-missing-deps \
    --module-path "tmp/BOOT-INF/classes:tmp/BOOT-INF/lib:tmp/org" \
    --recursive \
    -q \
    --multi-release ${TARGET_VER} \
    tmp/org tmp/BOOT-INF/classes tmp/BOOT-INF/lib/*.jar > jre-deps.info

# Delete the jre-deps.info upon exiting the script.
trap 'rm -rf jre-deps.info' EXIT

echo Running jlink...
#Run jlink to create the custom runtime.
jlink --strip-debug \
      --no-header-files \
      --no-man-pages \
      --compress=2 \
      --add-modules $(cat jre-deps.info) \
      --output $TARGET_FOLDER

echo Custom JRE has been created! Listing contents from: ${TARGET_FOLDER}

cd ${TARGET_FOLDER}
ls
# All commands were executed successfully, exit 0.
exit 0

