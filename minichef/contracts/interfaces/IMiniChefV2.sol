// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IMiniChefV2 {

    function pendingSynapse(uint256 _pid, address _user) external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount, address to) external;

    function withdraw(uint256 pid, uint256 amount, address to) external;

    function harvest(uint256 pid, address to) external;

    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external;

    function emergencyExit(uint pid, address to) external;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        uint128 accSushiPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (IMiniChefV2.UserInfo memory);

    function poolInfo(uint256 pid) external view returns (IMiniChefV2.PoolInfo memory);
}