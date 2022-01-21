// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface YieldLadle {
  function batch(bytes[] calldata calls) external payable returns(bytes[] memory results);
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface yVault {
  function deposit(uint amount) external returns (uint);
  function withdraw() external returns (uint);
}

interface IToken {
    function loanTokenAddress() external view returns (address);
    function flashBorrow(
        uint256 borrowAmount,
        address borrower,
        address target,
        string calldata signature,
        bytes calldata data
    ) external payable returns (bytes memory);
}

contract YieldLever {

  yVault constant yvUSDC = yVault(0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE);
  bytes6 constant ilkId = bytes6(0x303900000000); // for yvUSDC
  IToken constant iUSDC = IToken(0x32E4c68B3A4a813b710595AebA7f6B7604Ab9c15); 
  IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  address constant USDCJoin = address(0x0d9A1A773be5a83eEbda23bf98efB8585C3ae4f4);
  YieldLadle constant Ladle = YieldLadle(0x6cB18fF2A33e981D1e38A663Ca056c0a5265066A);
  address constant yvUSDCJoin = address(0x403ae7384E89b086Ea2935d5fAFed07465242B38);

  bytes4 private constant BUILD_SELECTOR = bytes4(keccak256("build(bytes6,bytes6,uint8)"));
  bytes4 private constant SERVE_SELECTOR = bytes4(keccak256("serve(bytes12,address,uint128,uint128,uint128)"));
  bytes4 private constant REPAY_SELECTOR = bytes4(keccak256("repayVault(bytes12,address,int128,uint128)"));
  bytes4 private constant CLOSE_SELECTOR = bytes4(keccak256("close(bytes12,address,int128,int128)"));

  address internal immutable dev;

  constructor() {
    dev = msg.sender;
  }

  function invest(
    uint256 baseAmount,
    uint256 borrowAmount,
    uint256 maxFyAmount,
    bytes6 seriesId // 0x303230350000 for FYUSDC05LP
  ) external {
    USDC.transferFrom(msg.sender, address(this), baseAmount);
    iUSDC.flashBorrow(
        borrowAmount,
        address(this),
        address(this),
        "",
        abi.encodeWithSignature("doInvest(bytes6,uint256,uint256)", seriesId, borrowAmount, maxFyAmount)
    );
  }

  function doInvest(
    bytes6 seriesId,
    uint256 borrowAmount,
    uint256 maxFyAmount
  ) external {
    uint totalBalance = USDC.balanceOf(address(this));
    USDC.approve(address(yvUSDC), totalBalance);
    // invest to yVault
    yvUSDC.deposit(totalBalance);
    uint yvUSDCBalance = IERC20(address(yvUSDC)).balanceOf(address(this));
    // transfer to yvUSDCJoin directly
    IERC20(address(yvUSDC)).transfer(yvUSDCJoin, yvUSDCBalance);
    // borrow from yield
    bytes[] memory ladleCallData = new bytes[](2);
    ladleCallData[0] = abi.encodeWithSelector(BUILD_SELECTOR, seriesId, ilkId, 0); // BUILD
    ladleCallData[1] = abi.encodeWithSelector(SERVE_SELECTOR, 0, address(this), yvUSDCBalance, borrowAmount, maxFyAmount); // SERVE
    Ladle.batch(ladleCallData);
    USDC.transfer(address(iUSDC), borrowAmount); // repay
  }

  function unwind(
    bytes12 vaultId, // get your vaultId from events emited in the invest() tx
    uint256 maxAmount,
    address pool, // get your pool address from the address of the "Trade" event emited in the invest() tx
    int128 ink // same, get it from the invest() tx, make it negative since we are going to withdraw here
  ) external {
    if (maxAmount != 0) {
      iUSDC.flashBorrow(
        maxAmount,
        address(this),
        address(this),
        "",
        abi.encodeWithSignature("doRepay(bytes12,address,int128)", vaultId, pool, ink)
      );
    } else {
      iUSDC.flashBorrow(
        uint256(uint128(-ink)),
        address(this),
        address(this),
        "",
        abi.encodeWithSignature("doClose(bytes12,address,int128)", vaultId, pool, ink)
      );
    }
  }
    

  function doRepay(bytes12 vaultId, address pool, int128 ink) external {
    uint256 borrowAmount = USDC.balanceOf(address(this));
    USDC.transfer(pool, borrowAmount);
    // repay yield
    bytes[] memory ladleCallData = new bytes[](1);
    ladleCallData[0] = abi.encodeWithSelector(REPAY_SELECTOR, vaultId, address(this), ink, borrowAmount); // REPAY
    Ladle.batch(ladleCallData);
    // withdraw from yvUSDC
    yvUSDC.withdraw();
    // repay
    USDC.transfer(address(iUSDC), borrowAmount);
    // send to user
    USDC.transfer(dev, USDC.balanceOf(address(this)));
  }

  function doClose(bytes12 vaultId, address pool, int128 ink) external {
    uint256 borrowAmount = USDC.balanceOf(address(this));
    USDC.approve(USDCJoin, borrowAmount);
    // repay yield
    bytes[] memory ladleCallData = new bytes[](1);
    ladleCallData[0] = abi.encodeWithSelector(CLOSE_SELECTOR, vaultId, address(this), ink, ink); // CLOSE
    Ladle.batch(ladleCallData);
    // withdraw from yvUSDC
    yvUSDC.withdraw();
    // repay
    USDC.transfer(address(iUSDC), borrowAmount);
    // send to user
    USDC.transfer(dev, USDC.balanceOf(address(this)));
  }
}
