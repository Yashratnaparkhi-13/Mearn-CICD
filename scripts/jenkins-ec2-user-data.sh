#!/bin/bash
set -Eeuo pipefail

exec > >(tee /var/log/jenkins-bootstrap.log | logger -t jenkins-bootstrap -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y java-21-amazon-corretto-headless docker nodejs npm gettext jq git unzip awscli-2

cat > /etc/yum.repos.d/jenkins.repo <<'REPO'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
gpgcheck=1
REPO
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
systemctl disable --now jenkins || true

systemctl enable --now docker
usermod -aG docker jenkins

KUBECTL_VERSION=v1.36.1
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod 0755 /usr/local/bin/kubectl

install -d -o jenkins -g jenkins -m 0750 /var/lib/jenkins/init.groovy.d
install -d -m 0750 /etc/jenkins
aws secretsmanager get-secret-value \
  --region ap-south-1 \
  --secret-id mern-cicd/jenkins-admin \
  --query SecretString \
  --output text > /etc/jenkins/admin-credentials.json
chown root:jenkins /etc/jenkins/admin-credentials.json
chmod 0640 /etc/jenkins/admin-credentials.json

cat > /var/lib/jenkins/init.groovy.d/security.groovy <<'GROOVY'
import groovy.json.JsonSlurper
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import hudson.security.HudsonPrivateSecurityRealm
import jenkins.model.Jenkins

def credentials = new JsonSlurper().parse(new File('/etc/jenkins/admin-credentials.json'))
def jenkins = Jenkins.get()
def realm = new HudsonPrivateSecurityRealm(false)
realm.createAccount(credentials.username as String, credentials.password as String)
jenkins.setSecurityRealm(realm)
def authorization = new FullControlOnceLoggedInAuthorizationStrategy()
authorization.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(authorization)
jenkins.save()
GROOVY
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/security.groovy
chmod 0640 /var/lib/jenkins/init.groovy.d/security.groovy

cat > /var/lib/jenkins/init.groovy.d/pipeline.groovy <<'GROOVY'
import hudson.plugins.git.GitSCM
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def jenkins = Jenkins.get()
def job = jenkins.getItem('MERN-CICD')
if (job == null) {
  job = jenkins.createProject(WorkflowJob.class, 'MERN-CICD')
}
job.setDefinition(new CpsScmFlowDefinition(
  new GitSCM('https://github.com/Yashratnaparkhi-13/Mearn-CICD.git'),
  '*/main'
))
job.setDescription('Tests, builds, and deploys the MERN app to the mern-cicd-eks staging namespace.')
job.setConcurrentBuild(false)
job.save()
jenkins.save()
GROOVY
chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/pipeline.groovy
chmod 0640 /var/lib/jenkins/init.groovy.d/pipeline.groovy

jenkins-plugin-cli --plugins workflow-aggregator git credentials-binding

mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<'SYSTEMD'
[Service]
Environment="JENKINS_JAVA_OPTIONS=-Xms256m -Xmx768m -Djava.awt.headless=true"
SYSTEMD
systemctl daemon-reload
systemctl enable --now jenkins
