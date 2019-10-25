#!/bin/bash
# ---------------------------------------------------------
# File Name : runTrialLogger.sh
# Author    : Alexey Yu. Illarionov, INI UZH Zurich
#             <ayuillarionov@ini.uzh.ch>
#
# Created   : Tue 21 Mar 2017 06:13:47 PM CET
# Modified  : Fri 19 Jul 2019 10:48:43 AM CEST
# Computer  : ZVPIXX
# System    : Linux 4.4.0-67-lowlatency x86_64 x86_64
#
# Purpose   : start trialLogger
#
# Usage     : bin/trialLogger -r <receive_ip>:<receive_port> -d <storage_directory>
#
# NOTE      : Check if firewall does not blocking the port: sudo ufw status
# ---------------------------------------------------------

bin/trialLogger -r 100.1.1.2:29001 -d /udpTrialLogger

