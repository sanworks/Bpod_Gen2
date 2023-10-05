"""
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod_Gen2 repository
Copyright (C) 2023 Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

----------------------------------------------------------------------------
"""

# Example code demonstrating basic usage of bpod_valve_driver.py to control the valve driver module via its USB port

from bpod_valve_driver import BpodValveDriver
import time

# Set the line below to match the valve driver's port on your system
usb_port_name = 'COM42'

V = BpodValveDriver(usb_port_name)  # Create an instance of the valve driver module
for i in range(1, 9):  # Open and close each valve once
    print('Valve ' + str(i) + ' open')
    V.set_valve(i, 1)
    time.sleep(0.5)
    print('Valve ' + str(i) + ' closed')
    V.set_valve(i, 0)
    time.sleep(0.5)
del V
