#!/bin/bash

#umask 002
export HOME=/data

if [ ! -e /data/eula.txt ]; then
  if [ "$EULA" != "" ]; then
    echo "# Generated via Docker on $(date)" > eula.txt
    echo "eula=$EULA" >> eula.txt
  else
    echo ""
    echo "Please accept the Minecraft EULA at"
    echo "  https://account.mojang.com/documents/minecraft_eula"
    echo "by adding the following immediately after 'docker run':"
    echo "  -e EULA=TRUE"
    echo ""
    exit 1
  fi
fi

VERSIONS_JSON=https://launchermeta.mojang.com/mc/game/version_manifest.json
TYPE=SPIGOT
DOWNLOAD_URL=https://ci.mcadmin.net/job/Spigot/lastSuccessfulBuild/artifact/spigot-1.11.2.jar

echo "Checking version information."
case "X$VERSION" in
  X|XLATEST|Xlatest)
    VANILLA_VERSION=`wget -O - -q $VERSIONS_JSON | jq -r '.latest.release'`
  ;;
  XSNAPSHOT|Xsnapshot)
    VANILLA_VERSION=`wget -O - -q $VERSIONS_JSON | jq -r '.latest.snapshot'`
  ;;
  X[1-9]*)
    VANILLA_VERSION=$VERSION
  ;;
  *)
    VANILLA_VERSION=`wget -O - -q $VERSIONS_JSON | jq -r '.latest.release'`
  ;;
esac

cd /data

function downloadServer {

  if [[ -n $DOWNLOAD_URL ]]; then
    echo "Downloading $DOWNLOAD_URL"
    wget -q -O $SERVER "$DOWNLOAD_URL"
    status=$?
    if [ $status != 0 ]; then
      echo "ERROR: failed to download from $DOWNLOAD_URL due to (error code was $status)"
      exit 3
    fi
  else
    echo "ERROR: Version $VANILLA_VERSION is not supported for $TYPE"
    echo "       Refer to https://mcadmin.net/ for supported versions"
    exit 2
  fi
}

function downloadPaper {
  local build
  case "$VERSION" in
    latest|LATEST|1.10)
      build="lastSuccessfulBuild";;
    1.9.4)
      build="773";;
    1.9.2)
      build="727";;
    1.9)
      build="612";;
    1.8.8)
      build="443";;
    *)
      build="nosupp";;
  esac

  if [ $build != "nosupp" ]; then
    downloadUrl="https://ci.destroystokyo.com/job/PaperSpigot/$build/artifact/paperclip.jar"
    wget -q -O $SERVER "$downloadUrl"
    status=$?
    if [ $status != 0 ]; then
      echo "ERROR: failed to download from $downloadUrl due to (error code was $status)"
      exit 3
    fi
  else
    echo "ERROR: Version $VERSION is not supported for $TYPE"
    echo "       Refer to https://ci.destroystokyo.com/job/PaperSpigot/"
    echo "       for supported versions"
    exit 2
  fi
}

function installForge {
  TYPE=FORGE
  norm=$VANILLA_VERSION

  echo "Checking Forge version information."
  case $FORGEVERSION in
    RECOMMENDED)
      wget -q -O /tmp/forge.json http://files.minecraftforge.net/maven/net/minecraftforge/forge/promotions_slim.json
      FORGE_VERSION=$(cat /tmp/forge.json | jq -r ".promos[\"$norm-recommended\"]")
      if [ $FORGE_VERSION = null ]; then
        FORGE_VERSION=$(cat /tmp/forge.json | jq -r ".promos[\"$norm-latest\"]")
        if [ $FORGE_VERSION = null ]; then
          echo "ERROR: Version $FORGE_VERSION is not supported by Forge"
          echo "       Refer to http://files.minecraftforge.net/ for supported versions"
          exit 2
        fi
      fi
      ;;

    *)
      FORGE_VERSION=$FORGEVERSION
      ;;
  esac

  # URL format changed for 1.7.10 from 10.13.2.1300
  sorted=$( (echo $FORGE_VERSION; echo 10.13.2.1300) | sort | head -1)
  if [[ $norm == '1.7.10' && $sorted == '10.13.2.1300' ]]; then
      # if $FORGEVERSION >= 10.13.2.1300
      normForgeVersion="$norm-$FORGE_VERSION-$norm"
  else
      normForgeVersion="$norm-$FORGE_VERSION"
  fi

  FORGE_INSTALLER="forge-$normForgeVersion-installer.jar"
  SERVER="forge-$normForgeVersion-universal.jar"

  if [ ! -e "$SERVER" ]; then
    echo "Downloading $FORGE_INSTALLER ..."
    wget -q http://files.minecraftforge.net/maven/net/minecraftforge/forge/$normForgeVersion/$FORGE_INSTALLER
    echo "Installing $SERVER"
    java -jar $FORGE_INSTALLER --installServer
  fi
}

function installFTB {
  TYPE=FEED-THE-BEAST

  echo "Looking for Feed-The-Beast server modpack."
  if [[ -z $FTB_SERVER_MOD ]]; then
      echo "Environment variable FTB_SERVER_MOD not set."
      echo "Set FTB_SERVER_MOD to the file name of the FTB server modpack."
      echo "(And place the modpack in the /data directory.)"
      exit 2
  fi
  local srv_modpack=${FTB_SERVER_MOD}
  if [[ ${srv_modpack:0:5} == "data/" ]]; then
      # Prepend with "/"
      srv_modpack=/${srv_modpack}
  fi
  if [[ ! ${srv_modpack:0:1} == "/" ]]; then
      # If not an absolute path, assume file is in "/data"
      srv_modpack=/data/${srv_modpack}
  fi
  if [[ ! -f ${srv_modpack} ]]; then
      echo "FTB server modpack ${srv_modpack} not found."
      exit 2
  fi
  if [[ ! ${srv_modpack: -4} == ".zip" ]]; then
      echo "FTB server modpack ${srv_modpack} is not a zip archive."
      echo "Please set FTB_SERVER_MOD to a file with a .zip extension."
      exit 2
  fi

  echo "Unpacking FTB server modpack ${srv_modpack} ..."
  local ftb_dir=/data/FeedTheBeast
  mkdir -p ${ftb_dir}
  unzip -o ${srv_modpack} -d ${ftb_dir}
  cp -f /data/eula.txt ${ftb_dir}/eula.txt
  FTB_SERVER_START=${ftb_dir}/ServerStart.sh
  chmod a+x ${FTB_SERVER_START}
}

function installVanilla {
  SERVER="minecraft_server.$VANILLA_VERSION.jar"

  if [ ! -e $SERVER ]; then
    echo "Downloading $SERVER ..."
    wget -q https://s3.amazonaws.com/Minecraft.Download/versions/$VANILLA_VERSION/$SERVER
  fi
}

echo "Checking type information."
case "$TYPE" in
  *BUKKIT|*bukkit|SPIGOT|spigot)
    case "$TYPE" in
      *BUKKIT|*bukkit)
        SERVER=craftbukkit_server.jar
        ;;
      *)
        SERVER=spigot_server.jar
        ;;
    esac

    if [ ! -f $SERVER ]; then
       downloadServer
    fi
    # normalize on Spigot for operations below
    TYPE=SPIGOT
  ;;

  PAPER|paper)
    SERVER=paper_server.jar
    if [ ! -f $SERVER ]; then
      downloadPaper
    fi
    # normalize on Spigot for operations below
    TYPE=SPIGOT
  ;;

  FORGE|forge)
    TYPE=FORGE
    installForge
  ;;

  FTB|ftb)
    TYPE=FEED-THE-BEAST
    installFTB
  ;;

  VANILLA|vanilla)
    installVanilla
  ;;

  *)
      echo "Invalid type: '$TYPE'"
      echo "Must be: VANILLA, FORGE, SPIGOT"
      exit 1
  ;;

esac


# If supplied with a URL for a world, download it and unpack
if [[ "$WORLD" ]]; then
case "X$WORLD" in
  X[Hh][Tt][Tt][Pp]*)
    echo "Downloading world via HTTP"
    echo "$WORLD"
    wget -q -O - "$WORLD" > /data/world.zip
    echo "Unzipping word"
    unzip -q /data/world.zip
    rm -f /data/world.zip
    if [ ! -d /data/world ]; then
      echo World directory not found
      for i in /data/*/level.dat; do
        if [ -f "$i" ]; then
          d=`dirname "$i"`
          echo Renaming world directory from $d
          mv -f "$d" /data/world
        fi
      done
    fi
    if [ "$TYPE" = "SPIGOT" ]; then
      # Reorganise if a Spigot server
      echo "Moving End and Nether maps to Spigot location"
      [ -d "/data/world/DIM1" ] && mv -f "/data/world/DIM1" "/data/world_the_end"
      [ -d "/data/world/DIM-1" ] && mv -f "/data/world/DIM-1" "/data/world_nether"
    fi
    ;;
  *)
    echo "Invalid URL given for world: Must be HTTP or HTTPS and a ZIP file"
    ;;
esac
fi

# If supplied with a URL for a modpack (simple zip of jars), download it and unpack
if [[ "$MODPACK" ]]; then
case "X$MODPACK" in
  X[Hh][Tt][Tt][Pp]*[Zz][iI][pP])
    echo "Downloading mod/plugin pack via HTTP"
    echo "$MODPACK"
    wget -q -O /tmp/modpack.zip "$MODPACK"
    if [ "$TYPE" = "SPIGOT" ]; then
      mkdir -p /data/plugins
      unzip -o -d /data/plugins /tmp/modpack.zip
    else
      mkdir -p /data/mods
      unzip -o -d /data/mods /tmp/modpack.zip
    fi
    rm -f /tmp/modpack.zip
    ;;
  *)
    echo "Invalid URL given for modpack: Must be HTTP or HTTPS and a ZIP file"
    ;;
esac
fi

function setServerProp {
  local prop=$1
  local var=$2
  if [ -n "$var" ]; then
    echo "Setting $prop to $var"
    sed -i "/$prop\s*=/ c $prop=$var" /data/server.properties
  fi

}

if [ ! -e server.properties ]; then
  echo "Creating server.properties"
  cp /tmp/server.properties .

  if [ -n "$WHITELIST" ]; then
    echo "Creating whitelist"
    sed -i "/whitelist\s*=/ c whitelist=true" /data/server.properties
    sed -i "/white-list\s*=/ c white-list=true" /data/server.properties
  fi

  setServerProp "motd" "$MOTD"
  setServerProp "allow-nether" "$ALLOW_NETHER"
  setServerProp "announce-player-achievements" "$ANNOUNCE_PLAYER_ACHIEVEMENTS"
  setServerProp "enable-command-block" "$ENABLE_COMMAND_BLOCK"
  setServerProp "spawn-animals" "$SPAWN_ANIMAILS"
  setServerProp "spawn-monsters" "$SPAWN_MONSTERS"
  setServerProp "spawn-npcs" "$SPAWN_NPCS"
  setServerProp "generate-structures" "$GENERATE_STRUCTURES"
  setServerProp "spawn-npcs" "$SPAWN_NPCS"
  setServerProp "view-distance" "$VIEW_DISTANCE"
  setServerProp "hardcore" "$HARDCORE"
  setServerProp "max-build-height" "$MAX_BUILD_HEIGHT"
  setServerProp "force-gamemode" "$FORCE_GAMEMODE"
  setServerProp "hardmax-tick-timecore" "$MAX_TICK_TIME"
  setServerProp "enable-query" "$ENABLE_QUERY"
  setServerProp "query.port" "$QUERY_PORT"
  setServerProp "enable-rcon" "$ENABLE_RCON"
  setServerProp "rcon.password" "$RCON_PASSWORD"
  setServerProp "rcon.port" "$RCON_PORT"
  setServerProp "max-players" "$MAX_PLAYERS"
  setServerProp "max-world-size" "$MAX_WORLD_SIZE"
  setServerProp "level-name" "$LEVEL"
  setServerProp "level-seed" "$SEED"
  setServerProp "pvp" "$PVP"
  setServerProp "generator-settings" "$GENERATOR_SETTINGS"
  setServerProp "online-mode" "$ONLINE_MODE"

  if [ -n "$LEVEL_TYPE" ]; then
    # normalize to uppercase
    LEVEL_TYPE=$( echo ${LEVEL_TYPE} | tr '[:lower:]' '[:upper:]' )
    echo "Setting level type to $LEVEL_TYPE"
    # check for valid values and only then set
    case $LEVEL_TYPE in
      DEFAULT|FLAT|LARGEBIOMES|AMPLIFIED|CUSTOMIZED)
        sed -i "/level-type\s*=/ c level-type=$LEVEL_TYPE" /data/server.properties
        ;;
      *)
        echo "Invalid LEVEL_TYPE: $LEVEL_TYPE"
	exit 1
	;;
    esac
  fi

  if [ -n "$DIFFICULTY" ]; then
    case $DIFFICULTY in
      peaceful|0)
        DIFFICULTY=0
        ;;
      easy|1)
        DIFFICULTY=1
        ;;
      normal|2)
        DIFFICULTY=2
        ;;
      hard|3)
        DIFFICULTY=3
        ;;
      *)
        echo "DIFFICULTY must be peaceful, easy, normal, or hard."
        exit 1
        ;;
    esac
    echo "Setting difficulty to $DIFFICULTY"
    sed -i "/difficulty\s*=/ c difficulty=$DIFFICULTY" /data/server.properties
  fi

  if [ -n "$MODE" ]; then
    echo "Setting mode"
    MODE_LC=$( echo $MODE | tr '[:upper:]' '[:lower:]' )
    case $MODE_LC in
      0|1|2|3)
        ;;
      su*)
        MODE=0
        ;;
      c*)
        MODE=1
        ;;
      a*)
        MODE=2
        ;;
      sp*)
        MODE=3
        ;;
      *)
        echo "ERROR: Invalid game mode: $MODE"
        exit 1
        ;;
    esac

    sed -i "/gamemode\s*=/ c gamemode=$MODE" /data/server.properties
  fi
fi


if [ -n "$OPS" -a ! -e ops.txt.converted ]; then
  echo "Setting ops"
  echo $OPS | awk -v RS=, '{print}' >> ops.txt
fi

if [ -n "$WHITELIST" -a ! -e white-list.txt.converted ]; then
  echo "Setting whitelist"
  echo $WHITELIST | awk -v RS=, '{print}' >> white-list.txt
fi

if [ -n "$ICON" -a ! -e server-icon.png ]; then
  echo "Using server icon from $ICON..."
  # Not sure what it is yet...call it "img"
  wget -q -O /tmp/icon.img $ICON
  specs=$(identify /tmp/icon.img | awk '{print $2,$3}')
  if [ "$specs" = "PNG 64x64" ]; then
    mv /tmp/icon.img /data/server-icon.png
  else
    echo "Converting image to 64x64 PNG..."
    convert /tmp/icon.img -resize 64x64! /data/server-icon.png
  fi
fi

# Make sure files exist to avoid errors
if [ ! -e banned-players.json ]; then
	echo '' > banned-players.json
fi
if [ ! -e banned-ips.json ]; then
	echo '' > banned-ips.json
fi

# If any modules have been provided, copy them over
[ -d /data/mods ] || mkdir /data/mods
for m in /mods/*.jar
do
  if [ -f "$m" ]; then
    echo Copying mod `basename "$m"`
    cp -f "$m" /data/mods
  fi
done
[ -d /data/config ] || mkdir /data/config
for c in /config/*
do
  if [ -f "$c" ]; then
    echo Copying configuration `basename "$c"`
    cp -rf "$c" /data/config
  fi
done

if [ "$TYPE" = "SPIGOT" ]; then
  if [ -d /plugins ]; then
    echo Copying any Bukkit plugins over
    cp -r /plugins /data
  fi
fi

if [[ $CONSOLE = false ]]; then
  EXTRA_ARGS=--noconsole
else
  EXTRA_ARGS=""
fi

if [[ ! -z $MAX_MEMORY ]]; then
  # put prior JVM_OPTS at the end to give any memory settings there higher precedence
  JVM_OPTS="-Xms${MAX_MEMORY} -Xmx${MAX_MEMORY} ${JVM_OPTS}"
fi
set -x
if [[ ${TYPE} == "FEED-THE-BEAST" ]]; then
    echo "Running FTB server modpack start ..."
    exec sh ${FTB_SERVER_START}
else
    # If we have a bootstrap.txt file... feed that in to the server stdin
    if [ -f /data/bootstrap.txt ];
    then
        exec java $JVM_XX_OPTS $JVM_OPTS -jar $SERVER "$@" $EXTRA_ARGS < /data/bootstrap.txt
    else
        exec java $JVM_XX_OPTS $JVM_OPTS -jar $SERVER "$@" $EXTRA_ARGS
    fi
fi