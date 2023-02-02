// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function decimal() external view returns (uint256);

    function balanceOf(address tokenOwner)
        external
        view
        returns (uint256 balance);

    function allowance(address tokenOwner, address spender)
        external
        view
        returns (uint256 remaining);

    function transfer(address to, uint256 tokens)
        external
        returns (bool success);

    function approve(address spender, uint256 tokens)
        external
        returns (bool success);

    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 tokens
    );
}

contract staking {
    struct user {
        uint256 totalDeposit;
        uint256 depositAmmount;
        uint256 startTime;
        uint256 endTime;
        uint256 claimedAt;
        uint256 totalYield;
        uint256 yieldPerday;
        uint256 yieldWithdrawn;
        uint256 counter;
        bool timeStarted;
        bool locked;
        address refferedBy;
        // uint256 teamId;
        bool referred;
    }

    mapping(address => user) public depositInfo;
    mapping(address => address[]) public teamInfo;
    // mapping(uint256 => address) public teamIds;
    mapping(uint256 => address[]) public weeklyTeams;
    mapping(address => mapping(uint256 => bool)) isLotteryClaimed;

    IERC20 BUSD;
    address public owner;
    address public ownerWallet;
    address public marketWallet;
    address public development;
    uint256 public lotteryPool;
    uint256 public deployTime;
    uint256 public currentTime;

    uint256 public minDepositTkns;
    uint256 public maxDepositTkns;
    uint256 public yield = 10;
    uint256 public wolfPacks = 20;
    uint256 public lockTime = 10 minutes;
    uint256 public dividendWithdrawal = 1 minutes;
    uint256 public accumlationCutoff = 10 days;
    uint256 public depositFee = 100;
    uint256 public referalFee = 15;
    uint256 public ownerFee = 30;
    uint256 public marketFee = 30;
    uint256 public developmentFee = 30;
    uint256 public lotteryFee = 10;
    uint256 public percentDivider = 1000;
    uint256[10] levels;

    constructor(
        address _tkn,
        address _ownerWallet,
        address _marketWallet
    ) {
        owner = msg.sender;
        BUSD = IERC20(_tkn);
        minDepositTkns = 50 * (10**BUSD.decimal());
        maxDepositTkns = 100000 * (10**BUSD.decimal());
        ownerWallet = _ownerWallet;
        marketWallet = _marketWallet;
        deployTime = block.timestamp;
    }

    function deposit(uint256 _ammount, address upliner) public {
        weeklyTimer();
        require(
            depositInfo[msg.sender].locked == false,
            "You already participated"
        );
        require(
            _ammount >= minDepositTkns && _ammount <= maxDepositTkns,
            "please enter minimum token ammounts"
        );
        require(upliner != msg.sender, "you can't reffer yourself");
        if (depositInfo[msg.sender].refferedBy == address(0)) {
            if (depositInfo[upliner].locked && upliner != address(0)) {
                depositInfo[msg.sender].refferedBy = upliner;
                depositInfo[upliner].counter++;
                BUSD.transferFrom(
                    msg.sender,
                    upliner,
                    ((_ammount * referalFee) / percentDivider)
                );
                // teamIds[depositInfo[upliner].counter++];
                depositInfo[msg.sender].referred = true;
            } else {
                depositInfo[msg.sender].refferedBy = address(0);
            }
        }
        uint256 _depositFee = (_ammount * depositFee) / percentDivider;
        uint256 _ownerFee = (_ammount * ownerFee) / percentDivider;
        uint256 _marketFee = (_ammount * marketFee) / percentDivider;
        uint256 _developmentFee = (_ammount * developmentFee) / percentDivider;
        lotteryPool += (_ammount * lotteryFee) / percentDivider;
        BUSD.transferFrom(msg.sender, ownerWallet, _ownerFee);
        BUSD.transferFrom(msg.sender, marketWallet, _marketFee);
        BUSD.transferFrom(msg.sender, development, _developmentFee);
        _ammount -= _depositFee;
        depositInfo[msg.sender].depositAmmount = _ammount;
        depositInfo[msg.sender].totalDeposit += _ammount;
        teamInfo[upliner].push(msg.sender);
        depositInfo[msg.sender].startTime = block.timestamp;
        depositInfo[msg.sender].endTime = block.timestamp + lockTime;
        BUSD.transferFrom(msg.sender, address(this), _ammount);
        weeklyTeams[currentTime].push(upliner);
        depositInfo[msg.sender].totalYield = ((_ammount * 600) /
            percentDivider);
        depositInfo[msg.sender].yieldPerday = ((_ammount * yield) /
            percentDivider);
        depositInfo[msg.sender].timeStarted = true;
        depositInfo[msg.sender].locked = true;
    }

    function withDraw() public {
        require(
            depositInfo[msg.sender].timeStarted == true,
            "your time is not started yet"
        );
        require(
            block.timestamp >=
                depositInfo[msg.sender].startTime + dividendWithdrawal,
            "you can't withdraw at that time"
        );
        calcYield();
    }

    function lottery() internal {
        // uint256 totalTeams = weeklyTeams[currentTime].length;
        uint256[] memory teamsTotalDeposit;
        uint256 winnerTeam;
        uint256 claimableReward = lotteryPool;
        lotteryPool = claimableReward;
        for (uint256 i = 0; i < weeklyTeams[currentTime].length; i++) {
            address upliner = weeklyTeams[currentTime][i];
            teamsTotalDeposit[i] = (calculateTeamTotalDeposit(upliner));
            if (teamsTotalDeposit[i] > teamsTotalDeposit[i - 1]) {
                winnerTeam = teamsTotalDeposit[i];
            } else {
                winnerTeam = teamsTotalDeposit[i - 1];
            }
        }
    }

    function claimLottery() public {
        require(!isLotteryClaimed[msg.sender][currentTime], "already claimed");
        uint256[] memory teamsTotalDeposit;
        // uint256 winnerTeam;
        uint256 claimableReward = lotteryPool;
        lotteryPool = claimableReward;
        for (uint256 i = 0; i < weeklyTeams[currentTime].length; i++) {
            address upliner = weeklyTeams[currentTime][i];
            teamsTotalDeposit[i] = (calculateTeamTotalDeposit(upliner));
            if (depositInfo[msg.sender].refferedBy == upliner) {
                uint256 claimReward = (((depositInfo[msg.sender]
                    .depositAmmount / teamsTotalDeposit[i]) * lotteryPool) /
                    100);
                BUSD.transferFrom(owner, msg.sender, claimReward);
            }
        }
    }

    function calcYield() internal {
        uint256 yieldTime = depositInfo[msg.sender].yieldPerday / 1 minutes;
        if (
            depositInfo[msg.sender].totalYield >=
            depositInfo[msg.sender].yieldWithdrawn
        ) {
            uint256 currentduration = (block.timestamp -
                depositInfo[msg.sender].startTime);
            uint256 _profit = yieldTime * currentduration;

            if (
                _profit + depositInfo[msg.sender].yieldWithdrawn >
                depositInfo[msg.sender].totalYield
            ) {
                uint256 remProfit = depositInfo[msg.sender].totalYield -
                    depositInfo[msg.sender].yieldWithdrawn;
                BUSD.transferFrom(owner, msg.sender, remProfit);
                depositInfo[msg.sender].yieldWithdrawn =
                    depositInfo[msg.sender].yieldWithdrawn +
                    remProfit;
            } else {
                BUSD.transferFrom(owner, msg.sender, _profit);
                depositInfo[msg.sender].yieldWithdrawn =
                    depositInfo[msg.sender].yieldWithdrawn +
                    _profit;
            }
        }
    }

    function weeklyTimer() public returns (uint256) {
        currentTime = (block.timestamp - deployTime) / 1 minutes;
        // require(currentTime > 7 days,"sorry time is not completed yet");
        return currentTime;
    }

    function weeklyLottery() public {
        if (currentTime != weeklyTimer()) {
            currentTime = weeklyTimer();
            lottery();
        }
    }

    function calculateTeamTotalDeposit(address upliner)
        public
        view
        returns (uint256)
    {
        uint256 sumOfTeamAmount = 0;
        for (uint256 i = 0; i < teamInfo[upliner].length; i++) {
            address memberAddress = teamInfo[upliner][i];
            sumOfTeamAmount += depositInfo[memberAddress].depositAmmount;
        }
        sumOfTeamAmount += depositInfo[upliner].depositAmmount;
        return sumOfTeamAmount;
    }

    function calcTeamReward(address _upliner) public returns (uint256) {
        uint256 sumOfTeamAmount = 0;
        uint256 teamReward = 0;
        // address[] memory memberAddress;
        // uint256 level = 0;
        for (uint256 i = 0; i < teamInfo[_upliner].length; i++) {
            address memberAddress = teamInfo[_upliner][i];
            sumOfTeamAmount += depositInfo[memberAddress].depositAmmount;
            if (i <= 2 && sumOfTeamAmount >= 5000 * (10**BUSD.decimal())) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 1) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 3 && sumOfTeamAmount >= 10000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 2) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 4 && sumOfTeamAmount >= 15000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 3) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 5 && sumOfTeamAmount >= 20000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 4) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 6 && sumOfTeamAmount >= 25000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 5) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 7 && sumOfTeamAmount >= 30000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 6) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 8 && sumOfTeamAmount >= 35000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 7) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 9 && sumOfTeamAmount >= 40000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 8) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 10 && sumOfTeamAmount >= 45000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 9) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            } else if (
                i <= 11 && sumOfTeamAmount >= 50000 * (10**BUSD.decimal())
            ) {
                teamReward =
                    (depositInfo[memberAddress].depositAmmount * 10) /
                    percentDivider;
                BUSD.transfer(memberAddress, teamReward);
            }
        }
        // return sumOfTeamAmount;
        return teamReward;
    }
}
