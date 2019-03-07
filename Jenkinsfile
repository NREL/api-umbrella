pipeline {
  agent {
    dockerfile {
      filename "Dockerfile-dev-build"
    }
  }
  triggers {
    cron("H H(0-5) * * *")
  }

  environment {
    CI = "true"
    HTTP_PORT = 9080
    HTTPS_PORT = 9081
  }

  stages {
    stage("build") {
      steps {
        sh "./configure"
        sh "make all test-deps"
        sh "make clean:dev"
      }
    }

    stage("lint") {
      steps {
        sh "make lint"
      }
    }

    stage("test") {
      steps {
        sh "env N=12 make test"
      }
    }
  }
}
