pipeline {
  agent any

  triggers {
    githubPush()
  }

  environment {
    // Pas dit aan als jouw csproj ergens anders staat
    PROJECT_PATH = 'frontend\\EasyDevOps.Frontend\\EasyDevOps.Frontend\\EasyDevOps.Frontend.csproj'
    OUTPUT_DIR   = 'out'
    CONFIG       = 'Release'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

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
        // Maak output map leeg/aan zodat je altijd schone artifacts hebt
        bat "if exist \"${env.OUTPUT_DIR}\" rmdir /s /q \"${env.OUTPUT_DIR}\""
        bat "mkdir \"${env.OUTPUT_DIR}\""

        bat "dotnet publish \"${env.PROJECT_PATH}\" -c ${env.CONFIG} -o \"${env.OUTPUT_DIR}\" --no-build"
      }
    }
  }

  post {
    always {
      // Archiveer publish output voor bewijs in je assessment
      archiveArtifacts artifacts: 'out/**', fingerprint: true, allowEmptyArchive: false
    }
  }
}
