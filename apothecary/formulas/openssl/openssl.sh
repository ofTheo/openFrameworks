#! /bin/bash
#
# openssl

# define the version
FORMULA_TYPES=( "osx" "vs" "msys2" "ios" "tvos" "android" )

VER=1.0.2h
VERDIR=1.0.2
CSTANDARD=gnu11 # c89 | c99 | c11 | gnu11
SITE=https://www.openssl.org
MIRROR=http://mirrors.ibiblio.org/openssl

# download the source code and unpack it into LIB_NAME
function download() {
	local FILENAME=openssl-$VER

	if ! [ -f $FILENAME ]; then
		wget ${MIRROR}/source/$FILENAME.tar.gz
	fi

	if ! [ -f $FILENAME.sha1 ]; then
		wget ${MIRROR}/source/$FILENAME.tar.gz.sha1
	fi
	if [ "$TYPE" == "vs" ] ; then
		#hasSha=$(cmd.exe /c 'call 'CertUtil' '-hashfile' '$FILENAME.tar.gz' 'SHA1'')
		echo "TO DO: check against the SHA for windows"
		tar -xf $FILENAME.tar.gz
		mv $FILENAME openssl
		rm $FILENAME.tar.gz
		rm $FILENAME.tar.gz.sha1
	else
		if [ "$(shasum $FILENAME.tar.gz | awk '{print $1}')" == "$(cat $FILENAME.tar.gz.sha1)" ] ;  then  
			tar -xvf $FILENAME.tar.gz
			mv $FILENAME openssl
			rm $FILENAME.tar.gz
			rm $FILENAME.tar.gz.sha1
		else 
			echoError "Invalid shasum for $FILENAME."
		fi
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {

	if [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
		# create output directories
		mkdir -p "src"
		mkdir -p "bin"
		mkdir -p "lib"

		mkdir -p lib/$TYPE
		mkdir -p lib/include

		mkdir -p build/$TYPE/i386
		mkdir -p build/$TYPE/x86_64
		mkdir -p build/$TYPE/armv7
        #mkdir -p build/$TYPE/armv7s
		mkdir -p build/$TYPE/arm64

		mkdir -p lib/$TYPE/i386
		mkdir -p lib/$TYPE/x86_64
		mkdir -p lib/$TYPE/armv7
        #mkdir -p lib/$TYPE/armv7s
		mkdir -p lib/$TYPE/arm64

		# make copies of the source files before modifying
		cp Makefile Makefile.orig
		cp Configure Configure.orig
		cp "crypto/ui/ui_openssl.c" "crypto/ui/ui_openssl.c.orig"
 	elif  [ "$TYPE" == "osx" ] ; then
		mkdir -p lib/$TYPE
		mkdir -p lib/include

        cp Makefile Makefile.orig
        cp Configure Configure1.orig

        #cp $FORMULA_DIR/Configure Configure
 	elif  [ "$TYPE" == "vs" ] ; then
		if patch -p1 -u -N --dry-run --silent < $FORMULA_DIR/winOpenSSL.patch 2>/dev/null ; then
			patch -p1 -u < $FORMULA_DIR/winOpenSSL.patch
		fi
	fi
}

# executed inside the lib src dir
function build() {
	
	if [ "$TYPE" == "osx" ] ; then	

        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
        rm -rf $BUILD_TO_DIR
        rm -f libcrypto.a libssl.a

        local BUILD_OPTS="-fPIC -stdlib=libc++ -mmacosx-version-min=${OSX_MIN_SDK_VER} no-shared"
        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/x86

        make clean && make dclean
	    KERNEL_BITS=32 ./config $BUILD_OPTS --openssldir=$BUILD_TO_DIR --prefix=$BUILD_TO_DIR
        make -j1 depend 
        make -j${PARALLEL_MAKE} 
		make -j 1 install


        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/x64
        make clean && make dclean
	    KERNEL_BITS=64 ./config $BUILD_OPTS --openssldir=$BUILD_TO_DIR --prefix=$BUILD_TO_DIR
        make -j1 depend 
        make -j${PARALLEL_MAKE} 
		make -j 1 install

        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
        cp -r $BUILD_TO_DIR/x64/* $BUILD_TO_DIR/

        lipo -create $BUILD_TO_DIR/x86/lib/libcrypto.a \
                     $BUILD_TO_DIR/x64/lib/libcrypto.a \
                     -output $BUILD_TO_DIR/lib/libcrypto.a

        lipo -create $BUILD_TO_DIR/x86/lib/libssl.a \
                     $BUILD_TO_DIR/x64/lib/libssl.a \
                     -output $BUILD_TO_DIR/lib/libssl.a

	 elif [ "$TYPE" == "vs" ] ; then
		CURRENTPATH=`pwd`
		cp -v $FORMULA_DIR/buildwin.cmd $CURRENTPATH
		WINPATH=$(echo "$CURRENTPATH" | sed -e 's/^\///' -e 's/\//\\/g' -e 's/^./\0:/')
		if [ $ARCH == 32 ] ; then
			if [ -d ms/Win32 ]; then
				rm -r ms/Win32
			fi
			mkdir ms/Win32
			cmd //c buildwin.cmd Win32 "${WINPATH}"
		elif [ $ARCH == 64 ] ; then
			if [ -d ms/x64 ]; then
				rm -r ms/x64
			fi
			mkdir ms/x64
			cmd //c buildwin.cmd x64 "${WINPATH}"
		fi
	# elif [ "$TYPE" == "msys2" ] ; then
	# 	# local BUILD_OPTS="--no-tests --no-samples --static --omit=CppUnit,CppUnit/WinTestRunner,Data/MySQL,Data/ODBC,PageCompiler,PageCompiler/File2Page,CppParser,PocoDoc,ProGen"

	# 	# # Locate the path of the openssl libs distributed with openFrameworks.
	# 	# local OF_LIBS_OPENSSL="../../../../libs/openssl/"

	# 	# # get the absolute path to the included openssl libs
	# 	# local OF_LIBS_OPENSSL_ABS_PATH=$(cd $(dirname $OF_LIBS_OPENSSL); pwd)/$(basename $OF_LIBS_OPENSSL)

	# 	# local OPENSSL_INCLUDE=$OF_LIBS_OPENSSL_ABS_PATH/include
	# 	# local OPENSSL_LIBS=$OF_LIBS_OPENSSL_ABS_PATH/lib/msys2

	# 	# ./configure $BUILD_OPTS \
	# 	# 			--include-path=$OPENSSL_INCLUDE \
	# 	# 			--library-path=$OPENSSL_LIBS \
	# 	# 			--config=MinGW

	# 	# make

	# 	# # Delete debug libs.
	# 	# lib/MinGW/i686/*d.a

	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then

		# This was quite helpful as a reference: https://github.com/x2on/OpenSSL-for-iPhone
		# Refer to the other script if anything drastic changes for future versions
		
		CURRENTPATH=`pwd`
		
		DEVELOPER=$XCODE_DEV_ROOT
		TOOLCHAIN=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain
		VERSION=$VER

        local IOS_ARCHS
        if [ "${TYPE}" == "tvos" ]; then 
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
        fi
		local STDLIB="libc++"

        SDKVERSION=""
        if [ "${TYPE}" == "tvos" ]; then 
            SDKVERSION=`xcrun -sdk appletvos --show-sdk-version`
        elif [ "$TYPE" == "ios" ]; then
            SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
        fi

		# Validate environment
		case $XCODE_DEV_ROOT in  
		     *\ * )
		           echo "Your Xcode path contains whitespaces, which is not supported."
		           exit 1
		          ;;
		esac
		case $CURRENTPATH in  
		     *\ * )
		           echo "Your path contains whitespaces, which is not supported by 'make install'."
		           exit 1
		          ;;
		esac 
			
        unset LANG
        local LC_CTYPE=C
        local LC_ALL=C

		# loop through architectures! yay for loops!
		for IOS_ARCH in ${IOS_ARCHS}
		do
			# make sure backed up
			cp "Configure" "Configure.orig" 
            cp "apps/speed.c" "apps/speed.c.orig" 
			cp "Makefile" "Makefile.orig"

			export THECOMPILER=$TOOLCHAIN/usr/bin/clang
			echo "The compiler: $THECOMPILER"

            ## Fix for tvOS fork undef 9.0
            if [ "${TYPE}" == "tvos" ]; then

            # Patch apps/speed.c to not use fork() since it's not available on tvOS
                sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "apps/speed.c"
                # Patch Configure to build for tvOS, not iOS
                sed -i -- 's/D\_REENTRANT\:.+OS/D\_REENTRANT\:tvOS/' "Configure"
                chmod u+x ./Configure 
            else
                sed -i -- 's/D\_REENTRANT\:.+OS/D\_REENTRANT\:iOS/' "Configure"
            fi

			if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]];
			then
				if [ "${TYPE}" == "tvos" ]; then 
                    PLATFORM="AppleTVSimulator"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneSimulator"
                fi
			else
				cp "crypto/ui/ui_openssl.c" "crypto/ui/ui_openssl.c.orig"
				sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
				if [ "${TYPE}" == "tvos" ]; then 
                    PLATFORM="AppleTVOS"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneOS"
                fi
			fi

			export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
			export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
			export BUILD_TOOLS="${DEVELOPER}"

            MIN_IOS_VERSION=$IOS_MIN_SDK_VER

            BITCODE=""
            if [[ "$TYPE" == "tvos" ]]; then
                BITCODE=-fembed-bitcode;
                MIN_IOS_VERSION=9.0
            fi


		    if [ "${TYPE}" == "tvos" ]; then 
                MIN_TYPE=-mtvos-version-min=
                if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
                    MIN_TYPE=-mtvos-simulator-version-min=
                fi
            elif [ "$TYPE" == "ios" ]; then
                MIN_TYPE=-miphoneos-version-min=
                if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
                    MIN_TYPE=-mios-simulator-version-min=
                fi
            fi

			export CC="${THECOMPILER}"
            export CFLAGS="-std=${CSTANDARD} $BITCODE -fPIC -stdlib=libc++ $MIN_TYPE$MIN_IOS_VERSION"
			mkdir -p "$CURRENTPATH/build/$TYPE/$IOS_ARCH"
			LOG="$CURRENTPATH/build/$TYPE/$IOS_ARCH/build-openssl-${VER}.log"
			
			
			echo "Compiler: $CC"
			echo "Building openssl-${VER} for ${PLATFORM} ${SDKVERSION} ${IOS_ARCH} : iOS Minimum=$MIN_IOS_VERSION"

			set +e
			if [ "${IOS_ARCH}" == "i386" ]; then
				echo "Configuring i386"
			    ./Configure darwin-i386-cc $CFLAGS no-asm --openssldir="$CURRENTPATH/build/$TYPE/$IOS_ARCH"
		    elif [ "${IOS_ARCH}" == "x86_64" ]; then
		    	echo "Configuring x86_64"
			    ./Configure darwin64-x86_64-cc $CFLAGS no-asm --openssldir="$CURRENTPATH/build/$TYPE/$IOS_ARCH"
		    else
		    	# armv7, armv7s, arm64
		    	echo "Configuring arm"
			    ./Configure iphoneos-cross $CFLAGS no-asm --openssldir="$CURRENTPATH/build/$TYPE/$IOS_ARCH"
		    fi

            sed -ie "s!^CFLAG=!CFLAG=-arch ${IOS_ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} !" "Makefile"

			echo "Running make for ${IOS_ARCH}"

			make depend
			make -j ${PARALLEL_MAKE}

			make install
			make clean && make dclean


			# reset source file back.
			cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"
            cp "apps/speed.c.orig" "apps/speed.c"
            cp "Makefile.orig" "Makefile"

		done

		unset CC CFLAG CFLAGS 
		unset PLATFORM CROSS_TOP CROSS_SDK BUILD_TOOLS
		unset IOS_DEVROOT IOS_SDKROOT 


        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
        cp -r $BUILD_TO_DIR/x86_64/* $BUILD_TO_DIR/

        if [ "${TYPE}" == "tvos" ]; then 
            lipo -create $BUILD_TO_DIR/arm64/lib/libcrypto.a \
                         $BUILD_TO_DIR/x86_64/lib/libcrypto.a \
                         -output $BUILD_TO_DIR/lib/libcrypto.a

            lipo -create $BUILD_TO_DIR/arm64/lib/libssl.a \
                         $BUILD_TO_DIR/x86_64/lib/libssl.a \
                         -output $BUILD_TO_DIR/lib/libssl.a
        elif [ "$TYPE" == "ios" ]; then
            lipo -create $BUILD_TO_DIR/armv7/lib/libcrypto.a \
                         $BUILD_TO_DIR/arm64/lib/libcrypto.a \
                         $BUILD_TO_DIR/i386/lib/libcrypto.a \
                         $BUILD_TO_DIR/x86_64/lib/libcrypto.a \
                         -output $BUILD_TO_DIR/lib/libcrypto.a

            lipo -create $BUILD_TO_DIR/armv7/lib/libssl.a \
                         $BUILD_TO_DIR/arm64/lib/libssl.a \
                         $BUILD_TO_DIR/i386/lib/libssl.a \
                         $BUILD_TO_DIR/x86_64/lib/libssl.a \
                         -output $BUILD_TO_DIR/lib/libssl.a
        fi

		cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"

		unset TOOLCHAIN DEVELOPER

	elif [ "$TYPE" == "android" ]; then
		perl -pi -e 's/install: all install_docs install_sw/install: install_docs install_sw/g' Makefile.org
		export _ANDROID_NDK_ROOT=$NDK_ROOT
		export FIPS_SIG=
		unset CXX
		unset CC
		unset AR
		rm -f Setenv-android.sh
		wget http://wiki.openssl.org/images/7/70/Setenv-android.sh
		perl -pi -e 's/^_ANDROID_EABI=(.*)$/#_ANDROID_EABI=\1/g' Setenv-android.sh
		perl -pi -e 's/^_ANDROID_ARCH=(.*)$/#_ANDROID_ARCH=\1/g' Setenv-android.sh
		perl -pi -e 's/^_ANDROID_API=(.*)$/#_ANDROID_API=\1/g' Setenv-android.sh
		perl -pi -e 's/\r//g' Setenv-android.sh
		export _ANDROID_API=$ANDROID_PLATFORM
		
        # armv7
        if [ "$ARCH" == "armv7" ]; then
            export _ANDROID_EABI=arm-linux-androideabi-4.9
		    export _ANDROID_ARCH=arch-arm
		elif [ "$ARCH" == "x86" ]; then
            export _ANDROID_EABI=x86-4.9
		    export _ANDROID_ARCH=arch-x86
		fi
		
        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/$ABI
        mkdir -p $BUILD_TO_DIR
        source Setenv-android.sh
        ./config --prefix=$BUILD_TO_DIR --openssldir=$BUILD_TO_DIR no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared
        make clean
        make -j1 depend 
        make -j${PARALLEL_MAKE} 
        make install
        make install

	else 

		echoWarning "TODO: build $TYPE lib"

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	#echoWarning "TODO: copy $TYPE lib"

	# # headers
    if [ -d $1/include/ ]; then
        # keep a copy of the platform specific headers
        find $1/include/openssl/ -name \opensslconf_*.h -exec cp {} $FORMULA_DIR/ \;
        # remove old headers
        rm -r $1/include/ 
        # restore platform specific headers
        find $FORMULA_DIR/ -name \opensslconf_*.h -exec cp {} $1/include/openssl/ \;
    fi
	
	mkdir -pv $1/include/openssl/
 	mkdir -p $1/lib/$TYPE
	
	# opensslconf.h is different in every platform, we need to copy
	# it as opensslconf_$(TYPE).h and use a modified version of 
	# opensslconf.h that detects the platform and includes the 
	# correct one. Then every platform checkouts the rest of the config
	# files that were deleted here
     if [[ "$TYPE" == "osx" || "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        if [ -f build/$TYPE/include/openssl/opensslconf.h ]; then
            mv build/$TYPE/include/openssl/opensslconf.h build/$TYPE/include/openssl/opensslconf_${TYPE}.h
        fi
        cp -RHv build/$TYPE/include/openssl/* $1/include/openssl/
        cp -v $FORMULA_DIR/opensslconf.h $1/include/openssl/opensslconf.h

    elif [ -f include/openssl/opensslconf.h ]; then
        mv include/openssl/opensslconf.h include/openssl/opensslconf_${TYPE}.h
        cp -RHv include/openssl/* $1/include/openssl/
        cp -v $FORMULA_DIR/opensslconf.h $1/include/openssl/opensslconf.h
    fi
	# suppress file not found errors
	#same here doesn't seem to be a solid reason to delete the files
	#rm -rf $1/lib/$TYPE/* 2> /dev/null

	# libs
	if [ "$TYPE" == "osx" ] ; then
		cp -v build/$TYPE/lib/libcrypto.a $1/lib/$TYPE/crypto.a
		cp -v build/$TYPE/lib/libssl.a $1/lib/$TYPE/ssl.a
	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
		cp -v build/$TYPE/lib/*.a $1/lib/$TYPE/
	elif [ "$TYPE" == "vs" ] ; then	 
		if [ $ARCH == 32 ] ; then
			rm -rf $1/lib/$TYPE/Win32
			mkdir -p $1/lib/$TYPE/Win32
			cp -v ms/Win32/lib/*.lib $1/lib/$TYPE/Win32/
			for f in $1/lib/$TYPE/Win32/*; do
				base=`basename $f .lib`
				mv -v $f $1/lib/$TYPE/Win32/${base}md.lib
			done
		elif [ $ARCH == 64 ] ; then
			rm -rf $1/lib/$TYPE/x64
			mkdir -p $1/lib/$TYPE/x64
			cp -v ms/x64/lib/*.lib $1/lib/$TYPE/x64/
			for f in $1/lib/$TYPE/x64/*; do
				base=`basename $f .lib`
				mv -v $f $1/lib/$TYPE/x64/${base}md.lib
			done
		fi
	# elif [ "$TYPE" == "msys2" ] ; then
	# 	mkdir -p $1/lib/$TYPE
	# 	cp -v lib/MinGW/i686/*.a $1/lib/$TYPE
	
	elif [ "$TYPE" == "android" ] ; then
	    if [ -d $1/lib/$TYPE/$ABI ]; then
	        rm -r $1/lib/$TYPE/$ABI
	    fi
	    mkdir -p $1/lib/$TYPE/$ABI
		cp -rv build/android/$ABI/lib/*.a $1/lib/$TYPE/$ABI/
	    mv include/openssl/opensslconf_android.h include/openssl/opensslconf.h

	# 	mkdir -p $1/lib/$TYPE/armeabi-v7a
	# 	cp -v lib/Android/armeabi-v7a/*.a $1/lib/$TYPE/armeabi-v7a

	# 	mkdir -p $1/lib/$TYPE/x86
	# 	cp -v lib/Android/x86/*.a $1/lib/$TYPE/x86
	else
	 	echoWarning "TODO: copy $TYPE lib"
	fi

    # copy license file
    rm -rf $1/license # remove any older files if exists
    mkdir -p $1/license
    cp -v LICENSE $1/license/
	
	
}

# executed inside the lib src dir
function clean() {
	echoWarning "TODO: clean $TYPE lib"
	if [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
		make clean
		# clean up old build folder
		rm -rf /build
		# clean up compiled libraries
		rm -rf /lib

		# reset files back to original if 
		cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"
		cp "Makefile.orig" "Makefile"
		cp "Configure.orig" "Configure"
	# if [ "$TYPE" == "vs" ] ; then
	# 	cmd //c buildwin.cmd ${VS_VER}0 clean static_md both Win32 nosamples notests
	# elif [ "$TYPE" == "android" ] ; then
	# 	export PATH=$PATH:$ANDROID_TOOLCHAIN_ANDROIDEABI/bin:$ANDROID_TOOLCHAIN_X86/bin
	# 	make clean ANDROID_ABI=armeabi
	# 	make clean ANDROID_ABI=armeabi-v7a
	# 	make clean ANDROID_ABI=x86
	# 	unset PATH
    elif [[ "$TYPE" == "osx" ]] ; then
        make clean
        # clean up old build folder
        rm -rf /build
        # clean up compiled libraries
        rm -rf /lib
        rm -rf *.a
	else
	 	make clean
	fi
}
