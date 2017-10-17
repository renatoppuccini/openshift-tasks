# 32 bit Java: dynatrace-java-env.sh
# 64 bit Java: dynatrace-java-env.sh 64
DT_DIR=`dirname -- "$0"`
. $DT_DIR/dynatrace-env.sh
export JAVA_OPTS="${JAVA_OPTS} -agentpath:$DT_DIR/agent/lib$1/liboneagentloader.so"
export JAVA_OPTIONS="${JAVA_OPTIONS} -agentpath:$DT_DIR/agent/lib$1/liboneagentloader.so"