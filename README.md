# Encoder/Motor/Gear Box 

The aim of this project is to develop a 3D-printed very low cost gear box for playing with robotics. It should 
cost less than $10 to make, yet include absolute positioning (meaning you can command the "servo" to move to any 
angle you choose) as well as continuous rotation with speed control and odometry. It should have a built-in 
motor controller and be simple to control from a microcontroller with I2C.

This project contains the Atmel Studio Project (currently mostly a test-bed for I2C communication), the OpenScad 3D model files, and the an Arduino program to test and control the GearBox.

The schematic/circuit design is at https://upverter.com/acshi/f8eb160d60b24aa1/Custom-Motor-Controller-w-Encoder/

![alt PCB](https://raw.githubusercontent.com/acshi/EncoderGearMotor/master/pcb.jpg)
