#!/bin/sh
# vim: et smartindent sr sw=4 ts=4:

# CAVEAT: script only works with single binary versions
# i.e versions greater than $XVER
#
# Use to install multiple versions of packer.
# and switch between them.
#
# /usr/local/bin/packer is symlinked to desired
# versioned one under /usr/local/bin.
#
# Also installs vim plugin if pathogen detected.
#
APP=packer
XVER=0.8.6
VER=${1:-$PACKER_VERSION}
BIN="/usr/local/bin"
ZIP="$BIN/${APP}-$VER.zip"

APK_TMP="/var/cache/apk"

if [[ -z "$VER" ]]; then
    echo "ERROR $0: you must supply a version of ${APP} to use"
    exit 1
fi

if [[ "$VER" == "list" ]] || [[ "$VER" == "show" ]] ; then

    # ... ideally we have recent sort that supports -V
    sort_opts="-rV"
    ! apk info | grep "^sort$" >/dev/null 2>&1 && sort_opts=""

    echo "Versions available under $BIN:"
    if [[ -L $BIN/${APP} ]]; then
        echo "using: $(ls -l $BIN/${APP} | sed -e 's/.* \([^ ]\+ -> [^ ]\+\)/\1/')"
    fi
    f=$(ls -1 $BIN/${APP}-* 2>/dev/null | sed -e 's/.*${APP}-//' | sort $sort_opts || echo "None found")
fi

if [[ $(echo -e "$VER\n$XVER" | sort -V | head -n 1) == "$VER" ]]; then
    echo "ERROR $0: script only works with versions greater than $XVER"
    exit 1
fi

if [[ -f $BIN/${APP} ]]; then
    if [[ -L $BIN/${APP} ]]; then
        if ! rm $BIN/${APP}
        then
            echo "ERROR $0: ... could not delete symlink $BIN/${APP}"
            exit 1
        fi
    elif [[ -x $BIN/${APP} ]]; then
        OLDVER=$($BIN/${APP} --version)
        if ! mv $BIN/${APP} $BIN/${APP}-$OLDVER
        then
            echo "ERROR $0: ... could not move existing to $BIN/${APP}-$OLDVER"
            exit 1
        fi
    else
        echo "ERROR $0: ... $BIN/${APP} is not a bin or symlink to bin"
        exit 1
    fi
fi

if [[ ! -x $BIN/${APP}-$VER ]]; then
    BASE_URI="https://releases.hashicorp.com/${APP}"
    DOWNLOAD_URI="$BASE_URI/$VER/${APP}_${VER}_linux_amd64.zip"

    REQ_PKGS="wget unzip ca-certificates"
    for p in $REQ_PKGS; do
        if ! apk info | grep "^${p}$" >/dev/null 2>&1
        then
            BUILD_PKGS="$BUILD_PKGS $p"
        fi
    done

    if [[ ! -z $(echo "$BUILD_PKGS" | sed -e 's/ //g') ]] ; then
        echo "INFO $0: installing helper pkgs"
        apk --no-cache add --update $BUILD_PKGS
    fi

    echo "INFO $0: ... downloading ${APP} $VER"
    if ! wget -q -T 60 -O $ZIP $DOWNLOAD_URI
    then
        echo "ERROR $0: could not download $VER from $DOWNLOAD_URI"
        echo "ERROR $0: ... are you sure it exists?"
        rm $ZIP >/dev/null 2>&1
        exit 1
    fi
    if ! unzip -p $ZIP | cat >$BIN/${APP}-$VER
    then
        echo "ERROR $0: could not extract ${APP} from zip"
        exit 1
    fi
    chmod a+x $BIN/${APP}-$VER
    rm -f $ZIP
else
    echo "INFO $0: ... $BIN/${APP}-$VER available ."
fi

echo "INFO $0: ... pointing $BIN/${APP} to $VER"
if ! ln -s $BIN/${APP}-$VER $BIN/${APP}
then
    echo "ERROR $0: could not repoint $BIN/${APP}"
    exit 1
fi

if ${APP} --version | grep "^${VER}$" 2>/dev/null
then
    echo "INFO $0: installed ${APP} $VER successfully"
else
    echo "INFO $0: failed to install"
    exit 1
fi

# ... install vim plugin if appropriate
if [[ -w /etc/vim/bundle ]] && [[ ! -d /etc/vim/bundle/vim-${APP} ]]; then
    echo "INFO $0: installing vim ${APP} plugin"
    if ! apk info | grep '^git$' >/dev/null 2>&1
    then
        BUILD_PKGS="$BUILD_PKGS git"
        apk --no-cache add --update git
    fi
    (
        cd /etc/vim/bundle
        git clone https://github.com/hashivim/vim-${APP}.git
        rm -rf vim-${APP}/.git
    )
fi

if [[ ! -z $(echo "$BUILD_PKGS" | sed -e 's/ //g') ]] ; then
    echo "INFO $0: deleting helper pkgs"
    apk --no-cache --purge del $BUILD_PKGS
fi

rm -rf $APK_TMP/* >/dev/null 2>&1

exit 0
