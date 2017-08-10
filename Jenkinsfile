#!groovy

// Run this node on a Maven Slave
// Maven Slaves have JDK and Maven already installed
node('maven') {
  // Make sure your nexus_openshift_settings.xml
  // Is pointing to your nexus instance
  def mvnCmd = "mvn -s ./nexus_openshift_settings.xml"

  stage('Checkout Source') {
    // Get Source Code from SCM (Git) as configured in the Jenkins Project
    // Next line for inline script, "checkout scm" for Jenkinsfile from Gogs
    //git 'http://gogs.shared-gogs.svc.cluster.local:3000/CICDLabs/openshift-tasks.git'
    //git 'http://gogs-rpp-gogs.apps.brz.example.opentlc.com/CICDLabs/openshift-tasks.git'
    checkout scm
  }

  // The following variables need to be defined at the top level and not inside
  // the scope of a stage - otherwise they would not be accessible from other stages.
  // Extract version and other properties from the pom.xml
  def groupId    = getGroupIdFromPom("pom.xml")
  def artifactId = getArtifactIdFromPom("pom.xml")
  def version    = getVersionFromPom("pom.xml")

  stage('Build war') {
    echo "Building version ${version}"

    sh "${mvnCmd} clean package -DskipTests"
  }
  stage('Unit Tests') {
    echo "Unit Tests"
    sh "${mvnCmd} test"
  }
  stage('Code Analysis') {
    echo "Code Analysis"

    // Replace shared-sonarqube with the name of your project
    sh "${mvnCmd} sonar:sonar -Dsonar.host.url=http://sonarqube.shared-sonar.svc:9000/ -Dsonar.projectName=${JOB_BASE_NAME}"
  }
  stage('Publish to Nexus') {
    echo "Publish to Nexus"

    // Replace shared-nexus with the name of your project
    sh "${mvnCmd} deploy -DskipTests=true -DaltDeploymentRepository=nexus::default::http://nexus3.shared-nexus.svc:8081/repository/releases"
  }

  stage('Build OpenShift Image') {
    def newTag = "TestingCandidate-${version}"
    echo "New Tag: ${newTag}"

    // Copy the war file we just built and rename to ROOT.war
    sh "cp ./target/openshift-tasks.war ./ROOT.war"

    // Start Binary Build in OpenShift using the file we just published
    // Replace shared-tasks-dev with the name of your dev project
    sh "oc project shared-tasks-dev"
    sh "oc start-build tasks --follow --from-file=./ROOT.war -n shared-tasks-dev"

    openshiftTag alias: 'false', destStream: 'tasks', destTag: newTag, destinationNamespace: 'shared-tasks-dev', namespace: 'shared-tasks-dev', srcStream: 'tasks', srcTag: 'latest', verbose: 'false'
  }

  stage('Deploy to Dev') {
    // Patch the DeploymentConfig so that it points to the latest TestingCandidate-${version} Image.
    // Replace shared-tasks-dev with the name of your dev project
    sh "oc project shared-tasks-dev"
    sh "oc patch dc tasks --patch '{\"spec\": { \"triggers\": [ { \"type\": \"ImageChange\", \"imageChangeParams\": { \"containerNames\": [ \"tasks\" ], \"from\": { \"kind\": \"ImageStreamTag\", \"namespace\": \"shared-tasks-dev\", \"name\": \"tasks:TestingCandidate-$version\"}}}]}}' -n shared-tasks-dev"

    openshiftDeploy depCfg: 'tasks', namespace: 'shared-tasks-dev', verbose: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyDeployment depCfg: 'tasks', namespace: 'shared-tasks-dev', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyService namespace: 'shared-tasks-dev', svcName: 'tasks', verbose: 'false'
  }

  stage('Integration Test') {
    // TBD: Proper test
    // Could use the OpenShift-Tasks REST APIs to make sure it is working as expected.

    def newTag = "ProdReady-${version}"
    echo "New Tag: ${newTag}"

    // Replace shared-tasks-dev with the name of your dev project
    openshiftTag alias: 'false', destStream: 'tasks', destTag: newTag, destinationNamespace: 'shared-tasks-dev', namespace: 'shared-tasks-dev', srcStream: 'tasks', srcTag: 'latest', verbose: 'false'
  }

  // Blue/Green Deployment into Production
  // -------------------------------------
  def dest   = "tasks-green"
  def active = ""

  stage('Prep Production Deployment') {
    // Replace shared-tasks-dev and shared-tasks-prod with
    // your project names
    sh "oc project shared-tasks-prod"
    sh "oc get route tasks -n shared-tasks-prod -o jsonpath='{ .spec.to.name }' > activesvc.txt"
    active = readFile('activesvc.txt').trim()
    if (active == "tasks-green") {
      dest = "tasks-blue"
    }
    echo "Active svc: " + active
    echo "Dest svc:   " + dest
  }
  stage('Deploy new Version') {
    echo "Deploying to ${dest}"

    // Patch the DeploymentConfig so that it points to
    // the latest ProdReady-${version} Image.
    // Replace shared-tasks-dev and shared-tasks-prod with
    // your project names.
    sh "oc patch dc ${dest} --patch '{\"spec\": { \"triggers\": [ { \"type\": \"ImageChange\", \"imageChangeParams\": { \"containerNames\": [ \"$dest\" ], \"from\": { \"kind\": \"ImageStreamTag\", \"namespace\": \"shared-tasks-dev\", \"name\": \"tasks:ProdReady-$version\"}}}]}}' -n shared-tasks-prod"

    openshiftDeploy depCfg: dest, namespace: 'shared-tasks-prod', verbose: 'false', waitTime: '', waitUnit: 'sec'
    openshiftVerifyDeployment depCfg: dest, namespace: 'shared-tasks-prod', replicaCount: '1', verbose: 'false', verifyReplicaCount: 'true', waitTime: '', waitUnit: 'sec'
    openshiftVerifyService namespace: 'shared-tasks-prod', svcName: dest, verbose: 'false'
  }
  stage('Switch over to new Version') {
    input "Switch Production?"

    // Replace shared-tasks-prod with the name of your
    // production project
    sh 'oc patch route tasks -n shared-tasks-prod -p \'{"spec":{"to":{"name":"' + dest + '"}}}\''
    sh 'oc get route tasks -n shared-tasks-prod > oc_out.txt'
    oc_out = readFile('oc_out.txt')
    echo "Current route configuration: " + oc_out
  }
}

// Convenience Functions to read variables from the pom.xml
def getVersionFromPom(pom) {
  def matcher = readFile(pom) =~ '<version>(.+)</version>'
  matcher ? matcher[0][1] : null
}
def getGroupIdFromPom(pom) {
  def matcher = readFile(pom) =~ '<groupId>(.+)</groupId>'
  matcher ? matcher[0][1] : null
}
def getArtifactIdFromPom(pom) {
  def matcher = readFile(pom) =~ '<artifactId>(.+)</artifactId>'
  matcher ? matcher[0][1] : null
}
