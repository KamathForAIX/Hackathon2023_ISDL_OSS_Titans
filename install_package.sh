#!/bin/bash

######### Global variables######
create_only_tar="yes"
oslevel=0
packagaNames=("")
i=0
arr=("temp1","temp2")
val=7.2
###########################

ver()  {
    printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' ');
}

usage() {
    echo "install_package.sh options are -o -t -c -p -h"
    echo ""
    echo "-p: Mandatory"
    echo "    For giving packages name to install/tar."
    echo "    After -p option add packages names. Ex: -p package1 package2"          
    echo ""
    echo "-o: Mandatory"
    echo "   For providing oslevel, supported levels are above version 7.1"    
    echo ""
    echo "-t: Optional"
    echo "   For creating just tar, for installation do not use this option"   
    echo "   also please run the script as a root priviledge for installation"
    echo ""
    echo "-c: Optional"
    echo "   For clearing cache directory /var/AutoInstaller-tmp/"
    echo ""
    echo "-h: Optional"
    echo "   For getting help"
    exit
}

#Too few Arguments
len=$#
if [ $len -lt 4 ]; then
        echo "Cannot process, please enter commnad correctly"
        usage
fi

#Clear cache and set if only tar file needed

create_only_tar="no"

args=$*
for var in $@;do
    arr[$i]="$var"
    i=`expr $i + 1`
done
 
i=0

# Compares the two packages version number
function cmp_version {
   large=$(echo  $1 $2 |
         awk '{ split($1, a, ".");
         split($2, b, ".");
         x = 0;
         for (i = 1; i <= 4; i++)
            if (a[i] < b[i]) {
                x = 3;
                break;
            } else if (a[i] > b[i]) {
                x = 2;
                break;
            }
           print x;
         }')
   return $large
}

# Compares the two packages release number
function cmp_release {
   arg1=`expr $1`
   arg2=`expr $2`
   echo $1 | grep "_" > /dev/null 2>&1
   ret1=$?
   echo $2 | grep "_" > /dev/null 2>&1
   ret2=$?
   if [[ $ret1 -eq 0 ]] && [[ $ret2 -eq 0 ]]
   then
       if [[ $arg1 <  $arg2 ]]
       then
          return 3
       elif [[ $arg1 >  $arg2 ]]
       then
          return 2
       fi
   else
       echo $2 | grep "_" > /dev/null 2>&1
       if [[ $? -eq 0 ]]
       then
           arg2=`echo $2  | grep "_" | sed 's/_.*//' | bc`
       fi
       if [[ $arg1 -lt $arg2 ]]
       then
          return 3
       elif [[ $arg1 -gt  $arg2 ]]
       then
          return 2
       fi
    fi
}

checkPackages()
{
    rpms_list=("")
    pkg_list=("")
    pkgname_list=("")
    pkg_name_ver_list=("")
    install_list=("")
    idx=0
        ls /var/AutoInstaller-tmp/$1/*.rpm | while read rpm_file
        do
        echo "##$rpm_file##"
                pkg_list[$idx]=`rpm -qp --qf "%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}" $rpm_file`
                pkgname_list[$idx]=`rpm -qp --qf "%{NAME}" $rpm_file`
                rpms_list[$idx]=`echo $rpm_file`
                pkg_name_ver_list[$idx]=`rpm -qp --qf "%{NAME}-%{VERSION}-%{RELEASE}" $rpm_file`
        $idx=`expr $idx + 1`
        done
        #let "pkg_count=0"
        pkg_count=${#pkg_list[*]}
        p=0
    echo $pkg_count
        while (( $p < $pkg_count ))
        do
                rpm -q --qf %{NAME} ${pkgname_list[$p]} > /dev/null 2>&1
                n_inst=$?
                if [[ $n_inst -eq 0 ]] # package with the same name is installed
                then
                        inst_pkgname=`rpm -q --qf %{NAME} ${pkgname_list[$p]}`
                        rpm -q --qf %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH} ${pkg_list[$p]} > /dev/null 2>&1
                        i_inst=$?
                        if [[ $i_inst -ne  0 ]] # package with exact version isn't installed
                        then
                                # check if rpm from dnf_bundle is higher version than the one installed.
                                inst_pkgname_ver=`rpm -q --qf %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH} ${pkgname_list[$p]}`
                                if [[ "${pkgname_list[$p]}" = "$inst_pkgname" ]]
                                then
                                        inst_ver=`rpm -q --qf %{VERSION} ${pkgname_list[$p]}`
                                        rpm_ver=`rpm -qp --qf %{VERSION} ${rpms_list[$p]}`
                                        cmp_version $inst_ver $rpm_ver
                                        rc1=$?
                                        if [[ $rc1 -eq 0 ]] # Same version matches. Check for the release.
                                        then
                                                inst_rel=`rpm -q --qf %{RELEASE} ${pkgname_list[$p]}`
                                                rpm_rel=`rpm -qp --qf %{RELEASE} ${rpms_list[$p]}`
                                                cmp_release $inst_rel $rpm_rel
                                                rc2=$?
                                                if [[ $rc2 -eq 3 ]] # Installed release is less than the bundle
                                                then
                                                        echo "$inst_pkgname_ver will be updated to ${pkg_name_ver_list[$p]}"
                                                        install_list[${#install_list[*]}+1]=${rpms_list[$p]}
                                                elif [[ $rc2 -eq 2 ]] # Higher version is already installed
                                                then
                                                        echo "Skipping ${pkg_name_ver_list[$p]} as higher version $inst_pkgname_ver is installed."
                                                fi
                                        elif [[ $rc1 -eq 3 ]] # Installed rpm lower than the bundle
                                        then
                                                echo "$inst_pkgname_ver will be updated to ${pkg_name_ver_list[$p]}"
                                                install_list[${#install_list[*]}+1]=${rpms_list[$p]}
                                        elif [[ $rc1 -eq 2 ]]
                                        then
                                                echo "Skipping ${pkg_name_ver_list[$p]} as higher version $inst_pkgname_ver is installed."
                                        fi
                                fi
                        elif [[ $i_inst -eq 0 ]] # exact version of the package is installed. Do nothing.
                        then
                                echo "${pkg_name_ver_list[$p]} is already installed"
                        fi
                elif [[ $n_inst -ne 0 ]] # package with the name isn't installed
                then
                        echo "${pkg_name_ver_list[$p]} will be installed"
                        install_list[${#install_list[*]}+1]=${rpms_list[$p]}
                fi
                (( p+=1 ))
                done

                if [[ ${#install_list[@]} -eq 0 ]]
                then
                        #echo "\n"
                        #echo "\nperl and all it's dependencies are already installed."
                        cd - >/dev/null 2>&1
                        rm -rf $tmppath
                        exit 0
                fi

                echo "Installing the packages..."
                rpm -Uvh ${install_list[@]}
                rc=$?
                if [[ $rc -eq 0 ]]
                then
                   #echo "\n"
                   #echo "perl and dependencies installed successfully."
                   cd - >/dev/null 2>&1
                   rm -rf $tmppath
                   exit 0
                elif [[ $rc -ne 0 ]]
                then
                   #echo "\n"
                   echo "perl and dependencies installation failed."
                   cd - >/dev/null 2>&1
                   rm -rf $tmppath
                   exit 1
        fi
}

for ((index=0; index < ${#arr[@]}; index++));do
        if [[ ${arr[$index]} =~ "-c" ]];
        then
                echo "Clearing your cache directory"
                if [[ -e /var/AutoInstaller-tmp/ ]];
                then
                        rm -rf /var/AutoInstaller-tmp/
                fi
    fi
        if [[ ${arr[$index]} =~ "-t" ]];
        then
                create_only_tar="yes"
    fi
        if [[ ${arr[$index]} =~ "-o" ]];
        then
            index=`expr $index + 1`
        oslevel=${arr[$index]}
        if [[ $(ver $oslevel) -lt $(ver $val) ]];
        then
            echo "Versions above 7.1 are supported"
            exit 
        fi
    fi
    if [[ ${arr[$index]} =~ "-h" ]]; 
    then
        usage
    fi
    if [[ ${arr[$index]} =~ "-p" ]];
    then
        index=`expr $index + 1`
        while [[ $index < ${#arr[@]} ]];do
            if [ '${arr[$index]}' = '-' ];then
                break
            else
                packageName[$i]=${arr[$index]}
            fi
                i=`expr $i + 1`
            index=`expr $index + 1`
        done
    fi
done

# Checking if the user has enetered package names or not
if [[ ${#packageName[@]} -eq 0 ]];then
    echo "Package list cannot be empty"
    usage
fi

# Checking if the oslevel has been provided or not
if [[ $oslevel =~ "0" ]];then
    echo "Please provide oslevel using -o option"
    usage
fi

if [[ ! -e /var/AutoInstaller-tmp/ ]];then
        mkdir /var/AutoInstaller-tmp/
fi
cd /var/AutoInstaller-tmp/
for ((index=0; index < ${#packageName[@]}; index++));do
    links=`/usr/bin/awk "/^${packageName[$index]}/{ f = 1;next } /^[a-z]/{ f = 0 } f;" /master_file`
    mkdir ${packageName[$index]} 2>&1 | tee /dev/null
    for l in $links;do
        if [[ $l =~ "$oslevel" && ( $l =~ "ppc/" || $l =~ "noarch" || $l =~ "ppc-") ]];then
                        rpmname=`echo "$l"|/usr/bin/awk -F/ '{print $NF}'`
                        if ! ls -l $rpmname >/dev/null 2>&1 ;then
                                cd ${packageName[$index]}
                                LDR_CNTRL=MAXDATA=0x80000000@DSA /usr/opt/perl5/bin/lwp-download $l
                                cp $rpmname ../
                                cd ../
                        else
                                cp $rpmname ${packageName[$index]}
                        fi
        fi
    done
    if [[ $create_only_tar == "yes" ]];
    then
        tar -cf ${packageName[$index]}.tar ${packageName[$index]}/*
    else
        rpm -ivh ${packageName[$index]}/*
        #checkPackages "${packageName[$index]}"
    fi
    rm -rf ${packageName[$index]}/
done

