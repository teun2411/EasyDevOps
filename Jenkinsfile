pipeline {
    agent any

    stages {
        stage('Build .NET Frontend') {
            steps {
                dir('frontend/EasyDevOps.Frontend/EasyDevOps.Frontend') {
                    bat 'dotnet --version'
                    bat 'dotnet restore'
                    bat 'dotnet build -c Release'
                }
            }
        }
    }
}
