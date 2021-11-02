// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Address.sol";

contract LavaXIDO is Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    IERC20 public _rewardsToken;
    IERC20 public _stakingToken;
    
    string private _name;
    
    uint256 private _minLimitAllow;
    uint256 private _maxLimitAllow;
    uint256 private _rewardsTokenRate;
    uint256 private _rewardsTokenTotalSupply;
    uint256 private _rewardsTokenReminingSupply;
    uint256 private _stakingTokenTotalRecived;
    
    address private _stakingTokenDestinationAddress;
    
    PoolStatus private _status;
    
    bool private _isLimitAllow;
    bool private _isRewardsTokenSupplyAdded;
    bool private _isStakingTokenSupplySendToDestinationAddress;
        
    enum PoolStatus{ Pending, Live, Ended, ReadyForRewardClam }
    
    mapping(address => bool) public _rewardsClaim;
    mapping(address => uint256) public _rewards;
    mapping(address => uint256) public _stakings;
        
    constructor(string memory name,
    address stakingTokenAddress,
    address rewardsTokenAddress,
    address stakingTokenDestinationAddress,
    uint256 minLimitAllow,
    uint256 maxLimitAllow,
    uint256 rewardsTokenRate,
    bool isLimitAllow){
        _name = name;
        
        _stakingTokenDestinationAddress = stakingTokenDestinationAddress;
        
        _stakingToken = IERC20(stakingTokenAddress);
        _rewardsToken = IERC20(rewardsTokenAddress);
        
        _isRewardsTokenSupplyAdded = false;
        _isStakingTokenSupplySendToDestinationAddress = false;
        _isLimitAllow = isLimitAllow;
        
        if (_isLimitAllow){
            if (minLimitAllow <= 0){
                revert("minimal allow limit should be grater then 0");
            }
            
            if (maxLimitAllow <= 0 || maxLimitAllow < minLimitAllow){
                revert("maximal allow limit should be grater then 0");
            }
            
            _minLimitAllow = minLimitAllow;
            _maxLimitAllow = maxLimitAllow;
        }
        
        if (rewardsTokenRate <= 0){
            revert("rewards token rate should be grater then 0");
        }
        
        _rewardsTokenRate = _rewardsTokenRate;
        
        _status = PoolStatus.Pending;
    }
    
    function getName() external view returns(string memory){
        return _name;
    }
    
    function getStakingTokenBalance(address account) external view returns(uint256){
        return _stakings[account];
    }
    
    function getRewardsTokenBalance(address account) external view returns(uint256){
        return _rewards[account];
    }
    
    function getStakingTokenTotalRecived() external view returns(uint256){
        return _stakingTokenTotalRecived;
    }
    
    function getRewardsTokenReminingSupply() external view returns(uint256){
        return _rewardsTokenReminingSupply;
    }
    
    function getRewardsTokenTotalSupply() external view returns(uint256){
        return _rewardsTokenTotalSupply;
    }
    
    function getRewardsTokenRate() external view returns(uint256){
        return _rewardsTokenRate;
    }
    
    function getMinLimitAllow() external view returns(uint256){
        return _minLimitAllow;
    }
    
    function getMaxLimitAllow() external view returns(uint256){
        return _maxLimitAllow;
    }
    
    function getIsLimitAllow() external view returns(bool){
        return _isLimitAllow;
    }
    
    function getIsRewardsTokenSupplyAdded() external view returns(bool){
        return _isRewardsTokenSupplyAdded;
    }
    
    function getIsStakingTokenSupplySendToDestinationAddress() external view returns(bool){
        return _isStakingTokenSupplySendToDestinationAddress;
    }
    
    function getRewardsClaimStatus(address account) external view returns(bool){
        return _rewardsClaim[account];
    }
    
    function getPoolStatus() external view returns(PoolStatus){
        return _status;
    }
    
    function setName(string memory name) external onlyOwner{
        _name = name;
    }
    
    function getStakingTokenDestinationAddress() external view returns(address){
        return _stakingTokenDestinationAddress;
    }
    
    function addRewardsTokenSupply(uint256 rewardsTokenSupply) external onlyOwner returns(bool){
        
        if (_isRewardsTokenSupplyAdded){
            revert("rewards token supply already added");
        }
        
        if (rewardsTokenSupply <= 0){
            revert("rewards token supply should be grater then 0");
        }
        
        bool transferFromStatus = _rewardsToken.transferFrom(msg.sender, address(this), rewardsTokenSupply);
        
        if (transferFromStatus){
            _isRewardsTokenSupplyAdded = true;
            _rewardsTokenTotalSupply = rewardsTokenSupply;
            _rewardsTokenReminingSupply = rewardsTokenSupply;
        }
        
        return transferFromStatus;
    }
    
    function setLived() external onlyOwner{
        
        if (!_isRewardsTokenSupplyAdded){
            revert("Rewards token supply not added");
        }
        
        if (_status == PoolStatus.Live){
            revert("Staking already live");
        }
        
        if (_status == PoolStatus.Pending && _status != PoolStatus.Ended && _status != PoolStatus.ReadyForRewardClam && _status != PoolStatus.Live){
            _status = PoolStatus.Live;
        } else {
            revert("Staking can not live");
        }
    }
    
    function setEnd() external onlyOwner{
        
        if (_status == PoolStatus.Ended){
            revert("Staking already Ended");
        }
        
        if (_status == PoolStatus.Live && _status != PoolStatus.Ended && _status != PoolStatus.ReadyForRewardClam && _status != PoolStatus.Pending){
            _status = PoolStatus.Ended;
        } else {
            revert("Staking can not Ended");
        }
    }
    
    function setReadyForRewardClam() external onlyOwner{
        
        if (_status == PoolStatus.ReadyForRewardClam){
            revert("Staking already Ready For Reward Clam");
        }
        
        if (_status == PoolStatus.Ended && _status != PoolStatus.Live && _status != PoolStatus.ReadyForRewardClam && _status != PoolStatus.Pending){
            _status = PoolStatus.ReadyForRewardClam;
        } else {
            revert("Staking can not Ready For Reward Clam");
        }
    }
    
    function sendStaking() external onlyOwner{
        
        if (_isStakingTokenSupplySendToDestinationAddress){
            revert("Staking token already sended");
        }
        
        if (_status != PoolStatus.Live && _status != PoolStatus.Pending){
            
            uint256 stakingTokenBalance = _stakingToken.balanceOf(address(this));
            bool transferStatus = _stakingToken.transferFrom(address(this), _stakingTokenDestinationAddress, stakingTokenBalance);
            
            if (transferStatus){
                _isStakingTokenSupplySendToDestinationAddress = true;
            }
            
        } else {
            revert("Staking token can not sended");
        }
    }
    
    function stake(uint256 amount) external{
        
        if (_status != PoolStatus.Live){
            revert("Staking is ended");
        }
        
        if (amount <= 0){
            revert("stake amount should be grater then 0");
        }
        
        uint256 stakingBalance = _stakings[msg.sender];
        uint256 rewardBalance = _rewards[msg.sender];
        
        uint256 checkamount = stakingBalance.add(amount);
        
        if (_isLimitAllow && (_minLimitAllow > checkamount) || (_maxLimitAllow < checkamount)){
            revert("staking limit not meet");
        }
        
        uint256 rewards = amount.div(_rewardsTokenRate);
        
        if (_rewardsTokenReminingSupply < rewards){
            revert("Amount is excced the stking");
        }
        
        bool transferStatus = _stakingToken.transferFrom(msg.sender, address(this), amount);
        
        if (transferStatus){
            _stakings[msg.sender] = stakingBalance.add(amount);
            _rewards[msg.sender] = rewardBalance.add(rewards);
            
            _rewardsTokenReminingSupply -= rewards;
        }
    }
    
    function claimRewards() external{
        
        if (_status == PoolStatus.ReadyForRewardClam){
            uint256 rewardBalance = _rewards[msg.sender];
            
            if (_rewardsClaim[msg.sender]){
                revert("rewards already claim");
            }
            
            if (rewardBalance > 0){
                bool transferStatus = _rewardsToken.transferFrom(msg.sender, address(this), rewardBalance);
                
                if (transferStatus){
                    _rewardsClaim[msg.sender] = true;
                }
            }
            
        } else {
            revert("can not claim rewards");
        }
    }
    
}