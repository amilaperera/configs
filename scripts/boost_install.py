#!/usr/bin/env python

"""
This script is used to install boost libraries on Windows & Linux systems.
Currently tested on,
    * Windows 10
    * Fedora 34

Usage: python3 boost_install.py -v 1.76 -p [PATH]

Once the boost libraries are installed, use -DBOOST_ROOT=<PATH> to change
the boost root directory to link against the required library version.

TODO:
    * Toolchain specification on command line.
    * Any other flags to bootstrap or b2 to tweak the build
    * Option to remove the files from the temp directories after installation
"""

import argparse
import os, errno
import tempfile
import urllib.request
import tarfile
import subprocess
from colorama import Fore, Style, init


def process(args):
    # retrive meta information from the provided arguments
    version, temp_dir, url, file_name = metainfo(args);

    # download boost from 'url' and store it in 'file_name'
    download(url, file_name)

    # extract boost to 'temp_dir'
    extract_directory = extract(temp_dir, file_name)

    # install
    prefix_arg = get_prefix(args.path, version)

    # run bootstrap
    bootstrap(prefix_arg, extract_directory)
    # run b2
    b2(prefix_arg, extract_directory)


def metainfo(args):
    version_with_dots = args.version + '.0'
    version_with_underscore = version_with_dots.replace('.', '_')

    temp_dir = tempfile.gettempdir();
    print(Fore.GREEN + 'Temp directory: '.format(temp_dir), end='')
    print('{}'.format(temp_dir))

    # name of the boost archive
    archive_name = 'boost_' + version_with_underscore + '.tar.gz'

    # destination file name
    file_name = os.path.join(temp_dir, archive_name)

    # url to retrieve
    url = 'https://boostorg.jfrog.io/artifactory/main/release/' + \
            version_with_dots + '/source/' + archive_name

    return version_with_dots, temp_dir, url, file_name


def download(url, dest):
    print(Fore.GREEN + 'Downloading: ', end='')
    print('{} into {}'.format(url, dest))

    # https://stackoverflow.com/questions/7243750/download-file-from-web-in-python-3
    # Download the file from `url` and save it locally under `dest`:
    with urllib.request.urlopen(url) as response, open(dest, 'wb') as out_file:
        data = response.read()
        out_file.write(data)


def extract(temp_dir, file_name):
    print(Fore.GREEN + 'Extracting: ', end='')
    dir_name = file_name.split('.')[0]
    print(dir_name)
    with tarfile.open(file_name) as tar:
        tar.extractall(temp_dir)
    return os.path.join(temp_dir, dir_name)


def get_prefix(path, version):
    # If --prefix is not not given we default to sane paths.
    # If --prefix is not sane, Windows & Linux use C:\Boost & /usr/local
    # respectively.
    # But this doesn't *often* create version directory nicely under the BOOST_ROOT
    # directory. Therefore we need to do the following manipulation if the path
    # is not set.

    # Either way, when building with CMake provide -DBOOST_ROOT=<path> to change
    # the boost version aginst with the project is linked.
    if not path:
        if os.name == 'nt':
            path = r'C:\boost\boost_' + version
        else:
            path = '/usr/local/boost_' + version

    # Normalize path name by collapsing redundant seprators.
    prefix_path = os.path.normpath(path)

    # Print install path information.
    print(Fore.GREEN + 'Install path: ', end='')
    print('{}'.format(prefix_path))

    # Set up the whole prefix argument.
    # This is needed both in bootstrap and build procedure.
    return '--prefix=' + prefix_path


def bootstrap(prefix_arg, extract_directory):
    if os.name == 'nt':
        cmd = ['bootstrap.bat']
    else:
        cmd = ['./bootstrap.sh']

    cmd.append(prefix_arg)

    # Print bootstrap command
    print(Fore.GREEN + 'Bootstrap command: ', end='')
    print('{}'.format(' '.join(cmd)))

    subprocess.run(cmd, shell=True, cwd=extract_directory)


def b2(prefix_arg, extract_directory):
    if os.name == 'nt':
        cmd = ['b2.exe', 'install', prefix_arg, '-j 8']
    else:
        cmd = ['sudo', './b2', 'install', prefix_arg, '-j 8']

    # Print build command
    print(Fore.GREEN + 'Build command: ', end='')
    print('{}'.format(' '.join(cmd)))

    args = {'cwd': extract_directory}
    # Windows needs shell=True for some reason even though b2.exe is not a shell builtin
    if os.name == 'nt':
        args.update({'shell': True})
    else:
        args.update({'check': True})

    subprocess.run(cmd, **args)


def main():
    parser = argparse.ArgumentParser(description='Install boost from source code')
    parser.add_argument('-v', '--version', required=True,
                        help='Boost version to be installed')
    parser.add_argument('-p', '--path', help='Installation path [C:\\boost\\boost_<ver> | /usr/local/boost_<ver>]')

    args = parser.parse_args()
    process(args)


if __name__ == '__main__':
    try:
        # Initialize colorama.
        # Automate sending reset sequences after each colored output.
        init(autoreset=True)
        main()

    except Exception as e:
        print('Error: ', end='')
        print(Fore.RED + '{}'.format(e))

