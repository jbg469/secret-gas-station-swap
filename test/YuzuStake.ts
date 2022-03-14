import { ethers } from "hardhat";
import { expect } from "chai";
import { advanceBlockTo ,latestNumber} from "./utilities"
import {Decimal} from 'decimal.js'


describe("YUZUStake", function () {
  before(async function () {
    this.ERC20MockWithDecimal = await ethers.getContractFactory("ERC20MockWithDecimal")
    this.YuzuStake = await ethers.getContractFactory("YUZUStake")
    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.carol = this.signers[2]
  })

  beforeEach(async function () {
    this.yuzu = await this.ERC20MockWithDecimal.deploy("YUZU","YUZU","10000000000000000000000",18)
    this.yuzuStake = await this.YuzuStake.deploy(this.yuzu.address);
  })

  it("xYUZU should have correct name and symbol and decimal", async function () {
    const name = await this.yuzuStake.name()
    const symbol = await this.yuzuStake.symbol()
    const decimals = await this.yuzuStake.decimals()
    const yuzuAddr =  await this.yuzuStake.yuzuTokenIns()
    expect(name).to.equal("xYUZU")
    expect(symbol).to.equal("xYUZU")
    expect(decimals).to.equal(18)
    expect(yuzuAddr).to.equal(this.yuzu.address)
  })

  it("set and update config  should works ok", async function () {
    await expect(this.yuzuStake.setConfig(0,0,0)).to.be.revertedWith("YuzuStake: config should exists.");
    await this.yuzuStake.addConfig(10,100);
    const beforeConf = await this.yuzuStake.configs(0);
    expect(beforeConf.blockCount).to.be.equal(10)
    expect(beforeConf.ratioBase10000).to.be.equal(100)

    await this.yuzuStake.setConfig(0,100,10000);

    const afterConf = await this.yuzuStake.configs(0);
    expect(afterConf.blockCount).to.be.equal(100)
    expect(afterConf.ratioBase10000).to.be.equal(10000)


    await expect(this.yuzuStake.connect(this.bob).setConfig(0,0,0)).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(this.yuzuStake.connect(this.bob).addConfig(10,10)).to.be.revertedWith("Ownable: caller is not the owner");
  })

  it("get ids should works well", async function () {
    await this.yuzuStake.addConfig(10,1000); //10 block 
    await this.yuzuStake.addConfig(20,10000); //10 block 

    const ten =  "10000000000000000000"
    const oneHundred =  "100000000000000000000"


    await this.yuzu.approve(this.yuzuStake.address,oneHundred)
    await this.yuzuStake.stake(oneHundred,0)


    const curreBlock = parseInt(await latestNumber())
    const orderInfo = await this.yuzuStake.orders(0)
    expect(orderInfo.status).to.be.equal(0);
    expect(orderInfo.from,this.alice.address);
    expect(orderInfo.stakedAt).to.be.equal(curreBlock);
    expect(orderInfo.stakeEndBlockNumber).to.be.equal(curreBlock + 10);
    expect(orderInfo.unstakedAt,this.alice.address);
    expect(orderInfo.unstakedEndBlockNumber).to.be.equal(0)
    expect(orderInfo.withdrawAt).to.be.equal(0);
    expect(orderInfo.depositAmount,oneHundred);
    expect(orderInfo.mintAmount,ten);

    await advanceBlockTo(curreBlock + 10)
    await expect(this.yuzuStake.connect(this.bob).unstake(0)).to.be.revertedWith("YuzuStake: not order owner")
    await this.yuzuStake.unstake(0)

    const currOrderInfo2 = await this.yuzuStake.orders(0);
    const curreBlock2 = parseInt(await latestNumber());
    (await expect(currOrderInfo2.status)).to.be.equal(1);
    (await expect(currOrderInfo2.unstakedAt)).to.be.equal(curreBlock2);




    await this.yuzu.approve(this.yuzuStake.address,oneHundred)
    await this.yuzuStake.stake(oneHundred,1)

    const oids = await this.yuzuStake.getOrderIds(this.alice.address)
    expect(  (await this.yuzuStake.getOrderIds(this.alice.address)).map(a=>parseInt(a))  ).to.eql([0,1])

    /*
      expect(await this.wluna.balanceOf(this.alice.address)).to.equal("0")

      await expect(this.wluna.wrap("100")).to.be.revertedWith("ERC20: transfer amount exceeds allowance")

      await this.luna.approve(this.wluna.address,"100")

      await this.wluna.wrap("100")
      expect(await this.luna.balanceOf(this.alice.address)).to.equal("900")
      expect(await this.wluna.balanceOf(this.alice.address)).to.equal("100000000000000")

      await this.wluna.unwrap("100000000000000")
      expect(await this.luna.balanceOf(this.alice.address)).to.equal("1000")
      */


    // await this.zoo.mint(this.alice.address, "1100")

    // await this.zoo.transfer(this.bob.address, "1000")
    // await this.zoo.transfer(this.carol.address, "10")
    // await this.zoo.connect(this.bob).transfer(this.carol.address, "100", {
    //   from: this.bob.address,
    // })
    // const totalSupply = await this.zoo.totalSupply()
    // const aliceBal = await this.zoo.balanceOf(this.alice.address)
    // const bobBal = await this.zoo.balanceOf(this.bob.address)
    // const carolBal = await this.zoo.balanceOf(this.carol.address)
    // expect(totalSupply, "1100")
    // expect(aliceBal, "90")
    // expect(bobBal, "900")
    // expect(carolBal, "110")
  })

  it("stake unstake and withdraw works well", async function () {
    await this.yuzuStake.addConfig(10,10000); //10 block 
    const ten =  "10000000000000000000"
    const oneHundred =  "100000000000000000000"
    const startYuzuBalance = await this.yuzu.balanceOf(this.alice.address)
    await this.yuzu.approve(this.yuzuStake.address,oneHundred)
    await this.yuzuStake.stake(oneHundred,0)


    let afterStakeYuzuBalance = await this.yuzu.balanceOf(this.alice.address)
    expect( ((new Decimal(startYuzuBalance.toString())).sub(new Decimal(afterStakeYuzuBalance.toString())).sub(new Decimal(oneHundred))).toNumber()  ).to.be.equal(0)


    // got xyuzu
    expect(await this.yuzuStake.balanceOf(this.alice.address) ).to.be.equal(oneHundred)
    // can't unstake
    await expect(this.yuzuStake.unstake(0)).to.be.revertedWith("YuzuStake: current block should exceed stakeEnd")
    const curreBlock = parseInt(await latestNumber())
    await advanceBlockTo(curreBlock + 15) //delay 5 blocks
    await this.yuzuStake.unstake(0)

    //xyuzu has been burnt
    expect(await this.yuzuStake.balanceOf(this.alice.address) ).to.be.equal("0x0")
    //can't withdraw
    await expect(this.yuzuStake.withdraw(0)).to.be.revertedWith("YuzuStake: current block should exceed unstakedEndBlockNumber")

    let orderInfo = await this.yuzuStake.orders(0)
    console.log(orderInfo.unstakedEndBlockNumber, " " ,curreBlock)
    await advanceBlockTo(orderInfo.unstakedEndBlockNumber)

    await this.yuzuStake.withdraw(0)
    expect(await this.yuzu.balanceOf(this.alice.address) ).to.be.equal(startYuzuBalance)

  })
  
})
