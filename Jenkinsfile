pipeline {
  agent any

  triggers { githubPush() }

  // Optioneel: voorkomt dubbele checkout (Declarative checkout + eigen checkout stage)
  options { skipDefaultCheckout(true) }

  environment {
    PROJECT_PATH = 'frontend\\EasyDevOps.Frontend\\EasyDevOps.Frontend.csproj'
    OUTPUT_DIR   = 'out'
    CONFIG       = 'Release'
    APP_LOG      = 'app.log'
    APP_URL      = 'http://localhost:5000'
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

    // --- Security check #1: NuGet dependency vulnerability check ---
    stage('Security: Dependency vulnerabilities') {
      steps {
        bat """
          echo === Vulnerable packages check ===
          dotnet list "${PROJECT_PATH}" package --vulnerable --include-transitive > vuln-packages.txt
          type vuln-packages.txt
        """
      }
    }

    // --- Security check #2: Trivy scan (portable exe, no choco needed) ---
    stage('Security: Trivy scan (fs)') {
      steps {
        bat """
          echo === Download Trivy (portable exe) ===
          if not exist tools mkdir tools
          if not exist tools\\trivy.exe (
            powershell -NoProfile -ExecutionPolicy Bypass -Command ^
              "$ProgressPreference='SilentlyContinue';" ^
              "Invoke-WebRequest -Uri 'https://github.com/aquasecurity/trivy/releases/latest/download/trivy_windows-64bit.zip' -OutFile 'tools\\\\trivy.zip';" ^
              "Expand-Archive -Force 'tools\\\\trivy.zip' 'tools';" ^
              "Remove-Item -Force 'tools\\\\trivy.zip'"
          )

          echo === Trivy filesystem scan (HIGH/CRITICAL) ===
          tools\\trivy.exe fs --scanners vuln,secret --severity HIGH,CRITICAL --format table --output trivy-report.txt .
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
        // Start de app op de achtergrond en log output naar app.log
        // Let op: draait op dezelfde Jenkins machine. Voor externe toegang open poort/firewall.
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
