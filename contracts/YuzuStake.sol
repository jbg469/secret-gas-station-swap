// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IYUZUStake {
    function stake(uint256 _amount, uint32 _cid) external;

    function unstake(uint256 _oid) external;

    function withdraw(uint256 _oid) external;

    function getOrderIds(address from) external  view returns (uint256[] memory);
}

// YuzuStake
contract YUZUStake is
    ERC20("xYUZU", "xYUZU"),
    Ownable,
    ReentrancyGuard,
    IYUZUStake
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Order status
    // Status transfer :
    // srcStatus   condition                          destStatus
    // init        call stake                           STAKING
    // STAKING     1. current block exceed stake end
    //             2. call stake                        UNSTAKED
    // UNSTAKED    1. current block exceed unstake end
    //             2. call withdraw                     WITHDRAW
    enum StakeOrderStatus {
        STAKING,
        UNSTAKED,
        WITHDRAW
    }

    // Stake order struct
    struct StakeOrder {
        StakeOrderStatus status; //current status of order
        address from; // who create this order
        uint256 stakedAt; // block number of call stake
        uint256 stakeEndBlockNumber; // block number of stake end
        uint256 unstakedAt; // block number of  call unstake
        uint256 unstakedEndBlockNumber; //block number of unstake end
        uint256 withdrawAt; //block number of call withdraw
        uint256 depositAmount; // amount of YUZU to deposit
        uint256 mintAmount; //amount of xYUZU to mint
    }

    struct StakeConfig {
        uint256 blockCount; // block count should staked last
        uint256 ratioBase10000; // ratio of xYUZU to mint based of 100000
    }

    //variables
    StakeOrder[] public orders; //global orders
    StakeConfig[] public configs; // global configs
    mapping(address => uint256[]) public userOrdreIds; // redundant index by from
    IERC20 public immutable yuzuTokenIns; // yuzu token

    //events
    event OrderCreated(
        uint256 oid,
        address from,
        uint256 stakedAt,
        uint256 stakeEndBlockNumber,
        uint256 depositAmount,
        uint256 mintAmount
    );
    event OrderUnstaked(
        uint256 oid,
        uint256 unstakedAt,
        uint256 unstakedEndBlockNumber
    );
    event OrderWithdrawed(uint256 oid, uint256 withdrawAt);
    event ConfigChanged(uint32 cid, uint256 blockCount, uint256 ratioBase10000);

    //modifier
    modifier configExists(uint32 _cid) {
        require(
            uint256(_cid) < configs.length,
            "YuzuStake: config should exists"
        );
        _;
    }

    modifier orderExists(uint256 _oid) {
        require(
            uint256(_oid) < orders.length,
            "YuzuStake: order should exists"
        );
        _;
    }

    //methods
    /// @param _yuzuToken  address of YUZU token
    constructor(IERC20 _yuzuToken) public {
        require(address(_yuzuToken) != address(0));
        yuzuTokenIns = _yuzuToken;
    }

    //admin function

    /// update stake's config by staked last block count and xYUZU mint ratio
    /// @param _cid  index of config
    /// @param _blockCount  address of YUZU token
    /// @param _ratioBase10000  address of YUZU token
    function setConfig(
        uint32 _cid,
        uint256 _blockCount,
        uint256 _ratioBase10000
    ) external configExists(_cid) onlyOwner {
        // set config
        StakeConfig storage stakeConfig = configs[_cid];
        stakeConfig.blockCount = _blockCount;
        stakeConfig.ratioBase10000 = _ratioBase10000;
        emit ConfigChanged(_cid, _blockCount, _ratioBase10000);
    }

    /// add stake's config by staked last block count and xYUZU mint ratio
    /// @param _blockCount  address of YUZU token
    /// @param _ratioBase10000  address of YUZU token
    function addConfig(uint256 _blockCount, uint256 _ratioBase10000)
        external
        onlyOwner
    {
        configs.push(
            StakeConfig({
                blockCount: _blockCount,
                ratioBase10000: _ratioBase10000
            })
        );
        emit ConfigChanged(
            uint32(configs.length - 1),
            _blockCount,
            _ratioBase10000
        );
    }

    /// Stake YUZU to mint xYUZU
    /// @param _amount amount  of yuzu to stake
    /// @param _cid  config index of StakeConfigs
    function stake(uint256 _amount, uint32 _cid)
        external
        override
        configExists(_cid)
        nonReentrant
    {
        // get config
        StakeConfig memory stakeConfig = configs[_cid];
        require(
            stakeConfig.blockCount > 0 && stakeConfig.ratioBase10000 > 0,
            "YuzuStake: Config should be inited"
        );
        // Transfer yuzu
        yuzuTokenIns.safeTransferFrom(msg.sender, address(this), _amount);
        // Mint  xyuzu
        uint256 mintAmount = _amount.mul(stakeConfig.ratioBase10000).div(10000);
        _mint(msg.sender, mintAmount);
        // Create order
        uint256 currentBlock = block.number;

        uint256 orderId = orders.length;
        uint256[] storage senderOrders = userOrdreIds[msg.sender];
        senderOrders.push(orderId);
        orders.push(
            StakeOrder({
                status: StakeOrderStatus.STAKING,
                from: msg.sender,
                stakedAt: currentBlock,
                stakeEndBlockNumber: currentBlock + stakeConfig.blockCount,
                unstakedAt: 0,
                unstakedEndBlockNumber: 0,
                withdrawAt: 0,
                depositAmount: _amount,
                mintAmount: mintAmount
            })
        );
        emit OrderCreated(
            orderId,
            msg.sender,
            currentBlock,
            currentBlock + stakeConfig.blockCount,
            _amount,
            mintAmount
        );
    }

    /// Unstake by burning xYUZU to get back YUZU, notice should still wait for unstake end before really withdrawing yuzu
    /// @param _oid order id
    function unstake(uint256 _oid)
        external
        override
        orderExists(_oid)
        nonReentrant
    {
        // get order
        StakeOrder storage stakeOrder = orders[_oid];
        require(stakeOrder.from == msg.sender, "YuzuStake: not order owner ");
        require(
            stakeOrder.status == StakeOrderStatus.STAKING,
            "YuzuStake: Order status need to be staking "
        );
        require(
            stakeOrder.stakeEndBlockNumber <= block.number,
            "YuzuStake: current block should exceed stakeEnd"
        );

        // Transfer xyuxu
        _burn(msg.sender, stakeOrder.mintAmount);

        // Update order status
        stakeOrder.status = StakeOrderStatus.UNSTAKED;
        stakeOrder.unstakedAt = block.number;

        uint256 freezeBlockCount = block.number -
            stakeOrder.stakeEndBlockNumber;
        uint256 maxFreezeBlock = stakeOrder.stakeEndBlockNumber -
            stakeOrder.stakedAt;
        if (freezeBlockCount > maxFreezeBlock) {
            freezeBlockCount = maxFreezeBlock;
        }
        stakeOrder.unstakedEndBlockNumber = block.number + freezeBlockCount;
        emit OrderUnstaked(_oid, block.number, block.number + freezeBlockCount);
    }

    /// Withdraw unstaked YUZU
    /// @param _oid order id
    function withdraw(uint256 _oid)
        external
        override
        orderExists(_oid)
        nonReentrant
    {
        StakeOrder storage stakeOrder = orders[_oid];
        require(stakeOrder.from == msg.sender, "YuzuStake: not order owner ");
        require(
            stakeOrder.status == StakeOrderStatus.UNSTAKED,
            "YuzuStake: Order status need to be unstaked "
        );
        require(
            stakeOrder.unstakedEndBlockNumber <= block.number,
            "YuzuStake: current block should exceed unstakedEndBlockNumber"
        );

        stakeOrder.withdrawAt = block.number;
        stakeOrder.status = StakeOrderStatus.WITHDRAW;
        //Transfer back yuzu
        yuzuTokenIns.safeTransfer(msg.sender, stakeOrder.depositAmount);
        emit OrderWithdrawed(_oid, block.number);
    }

    function configLength()
        external
        view
        returns (uint256)
    {
        return configs.length;
    }

    function orderLength()
        external
        view
        returns (uint256)
    {
        return orders.length;
    }

    function getOrderIds(address from)
        external
        view
        override
        returns (uint256[] memory ids)
    {
        return userOrdreIds[from];
    }

/*
    function getConfig(uint32 _cid)
        external
        returns (uint256 blockCount, uint256 ratioBase10000)
    {
        StakeConfig memory stakeConfig = configs[_cid];
        blockCount = stakeConfig.blockCount;
        ratioBase10000 = stakeConfig.ratioBase10000;
    }
    */
}
