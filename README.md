# Project 1

## 项目简述

该项目主要基于PULP-Platform的AXI项目。通过该项目的AXI交叉开关等组件来实现Mesh等拓扑网络，并基于AXI VIP来完成仿真验证。

## 项目文件结构

pulp-platform为相关文章、仿真结果等资料

axi_xbar: 
源代码均已整理至src文件夹
tb文件夹内是测试文件
axi和common_cells为头文件
doc是关键组件的结构图和简单的README
其它可参考开源项目：https://github.com/pulp-platform/axi

## 项目相关背景知识

需要熟悉片上网络、AXI协议、计算机体系结构、SystemVerilog测试平台、UVM等。
最好能掌握Gem5模拟器（其中Garnet针对NoC和存储系统的建模）的使用，这样可以进行一些架构级仿真，RTL在某些时候太过于笨重了。

## 项目运行环境 
* Questasim/VCS 10.7c                                                                    JTZ:仿真工具
* DC 2022.07（版本较旧可能会报error，需修改部分代码，如遇到相关BUG无法修复，请联系本人）   JTZ:综合工具
* Vrilator、VSC（与Questasim任选其一，推荐Questasim或VCS，能更好地支持UVM）             JTZ:验证工具（Questasim也可）
* JTZ:Vivado                                                                         JTZ:烧写工具

## 如何快速复现该项目

仿真前不要忘记装Bender！！！

阅读Makefile文件即可快速复现
例如make all一键编译仿真
make elab.log即DC综合
make compile.log仅编译不仿真
make sim_all仿真
注：默认为一键递归编译仿真，如需对部分组件进行仿真，则需修改相应的脚本文件。



JTZ:在linux上搞的？？
