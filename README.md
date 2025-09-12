# Foundry Airdrop

## Merkle Tree

```shell
forge install dmfxyz/murky
```


## Signature

### EIP-191

EIP-191 定义了一个通用的签名的格式，被签名的数据可以是任意数据

EIP-191 数据格式：`0x19 <1 byte version> <version specific data> <data to sign>`


| Version Byte | EIP    | Description                   |
|--------------|--------|-------------------------------|
| `0x00`       | 191    | Data with intended validator |
| `0x01`       | 712    | Structured data              |
| `0x45`       | 191    | `personal_sign` messages     |

**EIP-191 的描述核心：**

对象：任意数据 (any arbitrary data)

方法：添加版本化前缀 (a versioned prefix)

目的：防止签名重放攻击 (prevent replay attacks)


### EIP-712

EIP-712 是一种 **结构化数据签名标准**，主要用于 **链下签名和链上验证**。EIP-712 建立在 EIP-191 基础之上，通过 DomainSeparator 进一步强化了签名的安全性，防止重放攻击，并且规定了被签名数据的格式，方便将数据展示为人类可读的文本

#### EIP-712 的描述核心：

基础：基于 EIP-191 (extends EIP-191)

对象：结构化数据 (structured data)

方法：标准化编码与哈希 (standardized encoding and hashing)

首要目的：生成人类可读的签名提示 (generate human-readable signing prompts)

#### EIP-712 签名创建流程

##### Create Domain Separator Hash

```solidity
domainSeparatorTypeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
domainSeparatorHash = keccak256(domainSeparatorTypeHash, _hashedName, _hashedVersion, block.chainid, address(this))
```

##### Create Message Hash

```solidity
messageTypeHash = keccak256("Message(string content)")
messageHash = keccak256(abi.encode(messageTypeHash, keccak256(Message({ content: "hello" }))))
```

##### Create Digest

```solidity
digest = keccak256(hex"19_01", domainSeparatorHash, messageHash)
```

### EIP-191 和 EIP-712 之间的关系

EIP-191 数据格式：`0x19 <1 byte version> <version specific data> <data to sign>`

EIP-712 实际上就是固定了 `<version>` 为 `0x01`，并且规定了 `<version specific data>` 以及 `<data to sign>` 两个字段的格式，极大提升可读性


### ECDSA and ECDSA Signature

ECDSA 是椭圆曲线加密算法

## Transaction Type

### 特性

| 类型 | 名称 | EIP | 引入时间 | 主要特性 |
|------|------|-----|----------|----------|
| 0x00 | Legacy Transactions | - | 主网启动 | 原始交易格式，无类型字段 |
| 0x01 | Access List Transactions | EIP-2930 | 2021年 | 可选访问列表，减少gas成本 |
| 0x02 | EIP-1559 Transactions | EIP-1559 | 2021年 | 基础费用+优先费机制 |
| 0x03 | Blob Transactions | EIP-4844 | 2024年 | 为Layer 2设计的大数据存储 |
| 0x71 | EIP-712 Transactions | EIP-712 | - | 结构化数据签名，链下验证 |
| 0xff | Priority Transactions | 各链自定义 | 各异 | 私有链/侧链的特殊优先级交易 |

### 区别

🎯 核心区别总结

| 特性 | Type 0 | Type 1 | Type 2 | Type 3 |
|------|--------|--------|--------|--------|
| **Gas价格机制** | 固定 | 固定 | 动态(基础+优先) | 动态+blob gas |
| **访问列表** | 无 | 可选 | 可选 | 可选 |
| **主要用途** | 基础转账 | 优化合约交互 | 主流交易 | L2数据可用性 |
| **费用预测** | 困难 | 中等 | 容易 | 中等 |

### 使用场景

- 普通用户转账：Type 2 (EIP-1559)
- 复杂合约交互：Type 1 (Access List，如果需要)
- Layer 2数据提交：Type 3 (Blob Transactions)
- 链下授权：EIP-712签名
- 私有链特殊需求：自定义类型(如0xff)

### Transaction Type 0 (Legacy Transactions / 0x0)

#### 数据结构

```javascript
{
    nonce: 0,
    gasPrice: 1000000000, // 固定gas价格
    gasLimit: 21000,
    to: "0x...",
    value: 1000000000000000000,
    data: "0x",
    v: 27, // 签名部分
    r: "0x...",
    s: "0x..."
}
```

#### 特点：

- 最原始的交易格式
- 只有固定gas价格（gasPrice）
- 无类型字段，通过魔法恢复值区分
- 逐渐被新类型取代

### Transaction Type 1 (Optional Access Lists / 0x01 / EIP-2930)

```javascript
{
    type: 0x01,
    chainId: 1,
    nonce: 0,
    gasPrice: 1000000000,
    gasLimit: 21000,
    to: "0x...",
    value: 0,
    accessList: [ // 访问列表
        {
            address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
            storageKeys: ["0x0000000000000000000000000000000000000000000000000000000000000000"]
        }
    ],
    data: "0x"
}
```

#### 特点：

- 引入访问列表，预先声明要访问的存储位置
- 减少SLOAD操作的gas成本（从2600降到2100）
- 防止某些情况下的gas估算错误

### Transaction Type 2 (EIP-1559 Transactions / 0x02)

```javascript
{
    type: 0x02,
    chainId: 1,
    nonce: 0,
    maxPriorityFeePerGas: 2000000000, // 优先费
    maxFeePerGas: 30000000000,       // 最大费用
    gasLimit: 21000,
    to: "0x...",
    value: 1000000000000000000,
    data: "0x"
}
```

#### 特点：

- 基础费用：由协议自动计算并销毁
- 优先费：给矿工的小费
- 最大费用：用户愿意支付的上限
- 更好的费用预测和用户体验
- 当前以太坊主网的主要交易类型


### Transaction Type 3 (Blob Transactions / 0x03 / EIP-4844 / Proto-Danksharding)

```javascript
{
    type: 0x03,
    chainId: 1,
    nonce: 0,
    maxPriorityFeePerGas: 2000000000,
    maxFeePerGas: 30000000000,
    gasLimit: 21000,
    maxFeePerBlobGas: 1000000000,    // blob gas 费用上限
    blobVersionedHashes: ["0x01..."], // blob 数据哈希
    to: "0x...",
    value: 0,
    data: "0x"
}
```

#### 特点：

- 为Layer 2扩容解决方案设计
- Blob数据：大数据存储在信标链上，不在执行层
- 大幅降低数据可用性成本
- 支持Proto-Danksharding，为完整Danksharding做准备

### Type 113 (EIP-712 Transactions / 0x71)

```solidity
// EIP-712 结构化数据
struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
}

struct MyMessage {
    address user;
    uint256 amount;
    uint256 deadline;
}

// 链下签名，链上验证
bytes32 digest = keccak256(abi.encodePacked(
    "\x19\x01",
    domainSeparator,
    messageHash
));
```

#### 特点：

- 主要用于链下签名验证
- 提供人类可读的结构化数据签名
- 在dApps中广泛用于权限管理、MetaTransactions等
- 不是真正的链上交易类型，而是签名标准

### Type 255 (Priority Transactions / 0xff)

```javascript
// 私有链/侧链的特殊实现
{
    type: 0xff,
    nonce: 0,
    gasPrice: 0, // 可能免费或特殊定价
    gasLimit: 1000000,
    to: "0x...",
    value: 0,
    data: "0x...",
    priority: 1, // 优先级标志
    signature: "0x..." // 特殊签名方案
}
```

#### 特点：

- 非标准类型，各链自定义实现
- 用于私有链、联盟链、侧链的特殊需求
- 可能包含：零gas费用、优先打包权、特殊权限等
- 具体实现因链而异

