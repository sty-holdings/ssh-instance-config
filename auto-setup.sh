#!/bin/bash
#
# Description: This will configure an existing instance using ssh protocols.
#
# Installation:
#   Git client
#   Git credentials
#
# Copyright (c) 2022 STY-Holdings Inc
# MIT License
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to
# do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

set -eo pipefail

sh setup.sh -y configurations/yaml/local-ai2connect-as-root.yaml -k -W
sh setup.sh -y configurations/yaml/local-ai2connect-as-root.yaml -a -W
sh setup.sh -y configurations/yaml/local-ai2connect-as-root.yaml -U -W
sh setup.sh -y configurations/yaml/local-ai2connect-as-root.yaml -S -W
sh setup.sh -y configurations/yaml/local-ai2connect-as-ai2connect.yaml -c -W