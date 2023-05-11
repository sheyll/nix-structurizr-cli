{ lib, stdenv, fetchFromGitHub, jdk, gradle, perl, writeText, runtimeShell, makeWrapper, tree }:
let
  pname = "structurizr-cli";
  version = "1.30.0";

  src = fetchFromGitHub {
    owner = "structurizr";
    repo = "cli";
    rev = "v${version}";
    sha256 = "sha256-YJMuY0rpl8Q2twp/cd9GpmFkV4SXkIjIP3q0lTHaUzM=";
  };
  
  deps = stdenv.mkDerivation {
    name = "${pname}-deps";
    inherit src;

    nativeBuildInputs = [ jdk perl gradle ];

    buildPhase = ''
      export GRADLE_USER_HOME=$(mktemp -d);
      gradle --no-daemon build -x test
    '';

    # Mavenize dependency paths
    # e.g. org.codehaus.groovy/groovy/2.4.0/{hash}/groovy-2.4.0.jar -> org/codehaus/groovy/groovy/2.4.0/groovy-2.4.0.jar
    installPhase = ''
      find $GRADLE_USER_HOME/caches/modules-2 -type f -regex '.*\.\(jar\|pom\)' \
        | perl -pe 's#(.*/([^/]+)/([^/]+)/([^/]+)/[0-9a-f]{30,40}/([^/\s]+))$# ($x = $2) =~ tr|\.|/|; "install -Dm444 $1 \$out/$x/$3/$4/$5" #e' \
        | sh
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-wkOIMZJI4DajF2jCc0f9ZpLSL/+zBwVRqAbhctR0mgQ=";
  };

  # Point to our local deps repo
  gradleInit = writeText "init.gradle" ''
    settingsEvaluated { settings ->
      settings.pluginManagement {
        repositories {
          clear()
          maven { url '${deps}' }
        }
      }
    }
    logger.lifecycle 'Replacing Maven repositories with ${deps}...'
    gradle.projectsLoaded {
      rootProject.allprojects {
        buildscript {
          repositories {
            clear()
            maven { url '${deps}' }
          }
        }
        repositories {
          clear()
          maven { url '${deps}' }
        }
      }
    }
  '';

  
in stdenv.mkDerivation rec {
  inherit pname src version;

  nativeBuildInputs = [ jdk gradle makeWrapper tree ];

  buildPhase = ''
    runHook preBuild

    export GRADLE_USER_HOME=$(mktemp -d)
    gradle -PVERSION=${version} --offline --no-daemon --info --init-script ${gradleInit} build -x test

    runHook postBuild
    '';

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/java
        
    install -Dm644 build/libs/${pname}-${version}.jar $out/share/java
    install -Dm644 build/resources/main/application.properties $out/share/java
    
    classpath=$(find ${deps} -name "*.jar" -printf ':%h/%f');
    # create a wrapper that will automatically set the classpath
    # this should be the paths from the dependency derivation
    makeWrapper ${jdk}/bin/java $out/bin/${pname} \
          --add-flags "-classpath $out/share/java/${pname}-${version}.jar:''${classpath#:}" \
          --add-flags "-Dspring.config.location=$out/share/application.properties" \
          --add-flags "com.structurizr.cli.StructurizrCliApplication"
  '';

  meta = with lib; {
    description = "A command line utility for Structurizr.";
    homepage = "https://github.com/structurizr/cli/tree/v1.30.0";
    sourceProvenance = with sourceTypes; [
      fromSource
      binaryBytecode  # deps
    ];
    # license = licenses.apache2;
    platforms = platforms.all;
  };
}
