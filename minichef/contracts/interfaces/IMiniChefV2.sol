// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;

interface IMiniChefV2 {

    function pendingSynapse(uint256 _pid, address _user) external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount, address to) external;

    function withdraw(uint256 pid, uint256 amount, address to) external;

    function harvest(uint256 pid, address to) external;

    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external;

    function emergencyExit(uint pid, address to) external;

    function poolInfo(uint256 _pid)  external view returns (address, uint256, uint256, uint256);

    function userInfo(uint256 _pid, address user)
            external
            view
            returns (uint256, uint256);

}