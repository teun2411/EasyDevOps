pipeline {
  agent any

  triggers { githubPush() }

  environment {
    PROJECT_PATH = 'frontend\\EasyDevOps.Frontend\\EasyDevOps.Frontend.csproj'
    OUTPUT_DIR   = 'out'
    CONFIG       = 'Release'
    APP_LOG      = 'app.log'
    // Kies een poort die je wilt gebruiken
    APP_URL      = 'http://localhost:5000'
  }

  stages {
    stage('Verify .NET') {
      steps {
        bat 'dotnet --version'
      }
    }

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    // --- Security check #1: NuGet vulnerability check ---
    stage('Security: Dependency vulnerabilities') {
      steps {
        // 'dotnet list package --vulnerable' geeft exitcode 0, ook bij findings.
        // We laten de output zien en bewaren het als artifact.
        bat """
          echo === Vulnerable packages check ===
          dotnet list "${PROJECT_PATH}" package --vulnerable --include-transitive > vuln-packages.txt
          type vuln-packages.txt
        """
      }
    }

    // --- Security check #2: Trivy scan (filesystem scan) ---
    stage('Security: Trivy scan (fs)') {
      steps {
        // Installeer Chocolatey + Trivy indien nodig, daarna scan repo.
        bat """
          where trivy >nul 2>nul
          if %ERRORLEVEL% NEQ 0 (
            echo Trivy not found. Installing via Chocolatey...
            where choco >nul 2>nul
            if %ERRORLEVEL% NEQ 0 (
              echo Chocolatey not found. Installing Chocolatey...
              powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
            )
            choco install trivy -y
          )

          echo === Trivy filesystem scan ===
          trivy fs --scanners vuln,secret --severity HIGH,CRITICAL --format table --output trivy-report.txt .
          type trivy-report.txt
        """
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

    stage('Run (background)') {
      steps {
        // Start de app op de achtergrond en schrijf output naar app.log
        // ASPNETCORE_URLS zet poort/URL.
        // Let op: deze stap laat de app draaien na de build (handig als demo).
        bat """
          echo === Starting app in background ===
          if exist "${APP_LOG}" del "${APP_LOG}"
          set ASPNETCORE_URLS=${APP_URL}
          start /B cmd /c "cd /d %CD%\\${OUTPUT_DIR} && dotnet EasyDevOps.Frontend.dll >> ..\\${APP_LOG} 2>&1"
          timeout /t 3 >nul
          echo App should be running at ${APP_URL}
        """
      }
    }

    stage('Smoke test (HTTP)') {
      steps {
        // Simpele check of de webapp antwoord geeft
        bat """
          powershell -NoProfile -Command "try { (Invoke-WebRequest -UseBasicParsing '${APP_URL}' -TimeoutSec 10).StatusCode } catch { Write-Error $_; exit 1 }"
        """
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'out/**, vuln-packages.txt, trivy-report.txt, app.log', fingerprint: true, allowEmptyArchive: true
    }
  }
}
