#! /bin/bash

# Copyright (c) 2016 Cliqz GmbH. All rights reserved.
# Authors: Lucian Corlaciu <lucian@cliqz.com>
#          Max Breev <maxim@cliqz.com>

# Required ENVs:
# WIN32_REDIST_DIR
# CQZ_GOOGLE_API_KEY or MOZ_GOOGLE_API_KEY
# MOZ_MOZILLA_API_KEY
# CQZ_RELEASE_CHANNEL or MOZ_UPDATE_CHANNEL
# CQZ_CERT_DB_PATH
#
# Optional ENVs:
#  CQZ_BUILD_DE_LOCALIZATION - for build DE localization

set -e
set -x

source cliqz_env.sh

cd $SRC_BASE

if $CLOBBER; then
  ./mach clobber
fi

# TODO: Use MOZ_GOOGLE_API_KEY directly instead of CQZ_GOOGLE_API_KEY.
if [ $CQZ_GOOGLE_API_KEY ]; then
  export MOZ_GOOGLE_API_KEY=$CQZ_GOOGLE_API_KEY  # --with-google-api-keyfile=...
fi

if [ -z $MOZ_MOZILLA_API_KEY ]; then
  echo "warning: MOZ_MOZILLA_API_KEY environment variable is missing"
fi

if [ -z "$LANG" ]; then
  LANG='en-US'
fi

# for support old build
if [[ "$LANG" == 'de' ]]; then
  echo '***** German builds detected *****'
  export MOZ_UI_LOCALE=de
fi

# for localization repack
if [[ $IS_MAC_OS ]]; then
  export L10NBASEDIR=../../l10n  # --with-l10n-base=...
else
  export L10NBASEDIR=../l10n  # --with-l10n-base=...
fi

# process css for use theme in browser, not from extension
echo '***** Copy css from extension *****'
CLIQZ_EXT_URL='http://cdn2.cliqz.com/update/browser_beta/latest.xpi'
if [ $CQZ_BUILD_ID ]; then
  CLIQZ_EXT_URL='http://repository.cliqz.com/dist/'$CQZ_RELEASE_CHANNEL'/'$CQZ_VERSION'/'$CQZ_BUILD_ID'/cliqz@cliqz.com.xpi'
fi
wget -O cliqz@cliqz.com.xpi $CLIQZ_EXT_URL
if [ ! -d "browser/themes/linux/cliqz" ]; then mkdir browser/themes/linux/cliqz; fi
if [ ! -d "browser/themes/osx/cliqz" ]; then mkdir browser/themes/osx/cliqz; fi
if [ ! -d "browser/themes/windows/cliqz" ]; then mkdir browser/themes/windows/cliqz; fi
unzip -p cliqz@cliqz.com.xpi chrome/content/theme/styles/theme-linux.css > browser/themes/linux/cliqz/theme.css
unzip -p cliqz@cliqz.com.xpi chrome/content/theme/styles/theme-mac.css > browser/themes/osx/cliqz/theme.css
unzip -p cliqz@cliqz.com.xpi chrome/content/theme/styles/theme-win.css > browser/themes/windows/cliqz/theme.css
rm cliqz@cliqz.com.xpi

echo '***** Building *****'
./mach build

if [ $IS_WIN ]; then
  echo '***** Windows build installer *****'
  ./mach build installer
fi

echo '***** Packaging *****'

if [[ $IS_MAC_OS ]]; then
  MOZ_OBJDIR_BACKUP=$MOZ_OBJDIR
  unset MOZ_OBJDIR  # Otherwise some python script throws. Good job, Mozilla!
  make -C $OBJ_DIR package
  # Restore still useful variable we unset before.
  export MOZ_OBJDIR=$MOZ_OBJDIR_BACKUP
else
  ./mach package
fi

echo '***** Build DE language pack *****'
if [ $CQZ_BUILD_DE_LOCALIZATION ]; then
  cd $OLDPWD
  cd $SRC_BASE/$MOZ_OBJDIR/browser/locales
  $MAKE merge-de LOCALE_MERGEDIR=$(pwd)/mergedir
  $MAKE installers-de LOCALE_MERGEDIR=$(pwd)/mergedir
fi

echo '***** Build & package finished successfully. *****'
cd $OLDPWD
