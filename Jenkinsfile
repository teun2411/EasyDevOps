pipeline {
  agent any

  triggers {
    githubPush()
  }

  environment {
    PROJECT_PATH = 'frontend\\EasyDevOps.Frontend\\EasyDevOps.Frontend.csproj'
    OUTPUT_DIR   = 'out'
    CONFIG       = 'Release'
  }

  stages {
    stage('Verify .NET') {
      steps {
        bat 'dotnet --version'
      }
    }

    stage('Restore') {
      steps {
        bat "dotnet restore \"${env.PROJECT_PATH}\""
      }
    }

    stage('Build') {
      steps {
        bat "dotnet build \"${env.PROJECT_PATH}\" -c ${env.CONFIG} --no-restore"
      }
    }

    stage('Publish') {
      steps {
        bat "if exist \"${env.OUTPUT_DIR}\" rmdir /s /q \"${env.OUTPUT_DIR}\""
        bat "mkdir \"${env.OUTPUT_DIR}\""
        bat "dotnet publish \"${env.PROJECT_PATH}\" -c ${env.CONFIG} -o \"${env.OUTPUT_DIR}\" --no-build"
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'out/**', fingerprint: true, allowEmptyArchive: true
    }
  }
}
