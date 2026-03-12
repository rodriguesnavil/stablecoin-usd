# StablecoinUSD - Regulated ERC-20 Stablecoin

A production-quality, USD-pegged ERC-20 stablecoin smart contract built with OpenZeppelin.  
Demonstrates the core architecture used by regulated stablecoins like **USDC**, **USDT**, and **PYUSD**.

---

## What This Contract Does

| Feature | Description |
|---|---|
| **ERC-20 Standard** | Full `transfer`, `approve`, `transferFrom`, `balanceOf`, `totalSupply` |
| **Role-Based Access** | `MINTER_ROLE`, `COMPLIANCE_ROLE`, `PAUSER_ROLE` via OpenZeppelin AccessControl |
| **Mint & Burn** | Controlled token creation (deposit) and destruction (redemption) |
| **Blacklisting** | Permanently block sanctioned addresses (OFAC compliance) |
| **Freezing** | Temporarily lock accounts during AML investigations (reversible) |
| **Emergency Pause** | Circuit breaker that halts all transfers instantly |

---

## Contract Architecture

```
StablecoinUSD
├── ERC20          - Standard token interface (transfer, approve, etc.)
├── ERC20Burnable  - Burn extension
├── AccessControl  - Role-based permissions
└── Pausable       - Emergency stop mechanism

Compliance Layer (via _beforeTokenTransfer hook)
├── Blacklist mapping  - Permanent OFAC / court-order blocks
└── Freeze mapping     - Temporary investigation holds
```

---

## Role Hierarchy

```
DEFAULT_ADMIN_ROLE  →  Grants / revokes all roles
                        ⚠️  Use a Gnosis Safe multisig in production!
        │
        ├── MINTER_ROLE       →  mint() and burn()
        ├── COMPLIANCE_ROLE   →  blacklist / unBlacklist / freeze / unFreeze
        └── PAUSER_ROLE       →  pause() and unpause()
```

---

## Running in Remix IDE (Step-by-Step)

### Prerequisites
- A browser with [MetaMask](https://metamask.io) installed (optional for testnet deploy)
- Navigate to **[remix.ethereum.org](https://remix.ethereum.org)**

---

### Step 1 - Open Remix and Create the File

1. Open [https://remix.ethereum.org](https://remix.ethereum.org)
2. In the **File Explorer** panel (left sidebar), click the **📄 New File** icon
3. Name it `StablecoinUSD.sol`
4. Paste the entire contents of `contracts/StablecoinUSD.sol` into the editor

---

### Step 2 - Install OpenZeppelin (via Remix Package Manager)

Remix auto-resolves `@openzeppelin` imports. When you compile (Step 3), it will fetch the packages automatically.

If imports fail, manually install via the Remix terminal:

```bash
# In the Remix terminal (bottom panel):
npm install @openzeppelin/contracts
```

---

### Step 3 - Compile the Contract

1. Click the **☷ Solidity Compiler** icon in the left sidebar (looks like `<S>`)
2. Set compiler version to **`0.8.20`** or higher
3. Enable **optimization** - set runs to `200`
4. Click **Compile StablecoinUSD.sol**
5. You should see a green ✓ checkmark - no errors

---

### Step 4 - Deploy to the Remix JavaScript VM

> This runs entirely in your browser - no wallet or testnet ETH needed.

1. Click the **🚀 Deploy & Run Transactions** icon (left sidebar)
2. Under **Environment**, select **`Remix VM (Cancun)`**
3. Remix pre-loads 10 test accounts, each with 100 ETH - select **Account 0** (this will be your admin)
4. Under **Contract**, select `StablecoinUSD`
5. Expand the **Deploy** section - you need to fill in the constructor arguments:

```
defaultAdmin  →  paste Account 0 address  (your admin / multisig)
minter        →  paste Account 1 address  (backend minting system)
compliance    →  paste Account 2 address  (compliance officer)
pauser        →  paste Account 3 address  (security ops)
```

> **Tip:** Copy addresses from the **Account** dropdown at the top of the panel.

6. Click **Deploy** - the contract appears under **Deployed Contracts**

---

### Step 5 - Interact with the Contract

Expand the deployed contract to see all available functions. Try these in order:

#### ✅ Mint tokens (as Account 1 - MINTER_ROLE)

1. Switch **Account** to `Account 1` (the minter)
2. Find the **`mint`** function
3. Enter:
   - `to` → Account 0's address
   - `amount` → `1000000000` (= 1,000 SUSD with 6 decimals)
4. Click **mint** - transaction confirms instantly

#### ✅ Check balance

1. Find **`balanceOf`**
2. Enter Account 0's address
3. Click - returns `1000000000`

#### ✅ Transfer tokens (as Account 0)

1. Switch to **Account 0**
2. Find **`transfer`**
3. Enter:
   - `to` → Account 4's address
   - `amount` → `100000000` (= 100 SUSD)
4. Click **transfer**

#### 🔴 Blacklist an address (as Account 2 - COMPLIANCE_ROLE)

1. Switch to **Account 2**
2. Find **`blacklist`**
3. Enter Account 4's address
4. Click **blacklist** - Account 4 is now blocked

#### ❌ Verify blacklist blocks transfers

1. Switch to **Account 0**
2. Try to `transfer` to Account 4's address
3. Transaction **reverts** with: `StablecoinUSD: recipient is blacklisted` ✓

#### 🧊 Freeze an account (as Account 2)

1. Stay on Account 2
2. Find **`freeze`**
3. Enter Account 5's address → click **freeze**
4. Try to mint to Account 5 - reverts ✓

#### ⏸ Pause the contract (as Account 3 - PAUSER_ROLE)

1. Switch to **Account 3**
2. Find **`pause`** → click it
3. Try any transfer - reverts with `Pausable: paused` ✓
4. Click **`unpause`** to resume

#### 🔥 Burn tokens (as Account 1)

1. Switch to **Account 1**
2. Find **`burn`**
3. Enter:
   - `from` → Account 0's address
   - `amount` → `500000000` (= 500 SUSD)
4. Click **burn** - totalSupply decreases

---

### Step 6 - Deploy to a Public Testnet (Optional)

> Requires MetaMask and free testnet ETH from a faucet.

1. Install **MetaMask** → connect to **Sepolia Testnet**
2. Get free Sepolia ETH from [sepoliafaucet.com](https://sepoliafaucet.com)
3. In Remix, change **Environment** → `Injected Provider - MetaMask`
4. MetaMask will prompt you to connect - approve
5. Deploy exactly as in Step 4
6. After deployment, copy the **contract address**
7. View your live contract on [sepolia.etherscan.io](https://sepolia.etherscan.io)

---

## Function Reference

### Token Operations

| Function | Role Required | Description |
|---|---|---|
| `mint(address to, uint256 amount)` | `MINTER_ROLE` | Create new tokens - simulates fiat deposit |
| `burn(address from, uint256 amount)` | `MINTER_ROLE` | Destroy tokens - simulates fiat redemption |
| `transfer(address to, uint256 amount)` | Token holder | Standard ERC-20 transfer |
| `approve(address spender, uint256 amount)` | Token holder | Authorise a spender |
| `transferFrom(address from, address to, uint256 amount)` | Approved spender | Transfer on behalf of owner |

### Compliance Operations

| Function | Role Required | Description |
|---|---|---|
| `blacklist(address account)` | `COMPLIANCE_ROLE` | Permanently block - OFAC / court order |
| `unBlacklist(address account)` | `COMPLIANCE_ROLE` | Remove from blacklist (false positive only) |
| `freeze(address account)` | `COMPLIANCE_ROLE` | Temporarily lock - AML investigation |
| `unFreeze(address account)` | `COMPLIANCE_ROLE` | Restore access after investigation clears |
| `pause()` | `PAUSER_ROLE` | Halt ALL transfers - security incident |
| `unpause()` | `PAUSER_ROLE` | Resume after incident is resolved |

### View Functions

| Function | Description |
|---|---|
| `balanceOf(address)` | Token balance of an address |
| `totalSupply()` | Total tokens in circulation |
| `allowance(owner, spender)` | Approved spending limit |
| `blacklisted(address)` | Returns `true` if address is blacklisted |
| `frozen(address)` | Returns `true` if address is frozen |
| `paused()` | Returns `true` if contract is paused |

---

## Common Errors & What They Mean

| Error Message | Cause | Fix |
|---|---|---|
| `StablecoinUSD: recipient is blacklisted` | Sending to a blacklisted address | Use a different recipient |
| `StablecoinUSD: sender is blacklisted` | Sending from a blacklisted address | Address permanently blocked |
| `StablecoinUSD: account is frozen` | Account temporarily locked | Wait for compliance to unfreeze |
| `Pausable: paused` | Contract is paused | Wait for `unpause()` |
| `AccessControl: account is missing role` | Calling a function without the required role | Switch to an account with the correct role |

---

## Real-World Parallels

| This Contract | Real World |
|---|---|
| `mint()` | Circle receives $1M USD → mints 1M USDC |
| `burn()` | User redeems USDC → Circle burns tokens, wires USD |
| `blacklist()` | OFAC sanctions list → Circle blocks Tornado Cash addresses |
| `freeze()` | AML alert → compliance locks account pending investigation |
| `pause()` | Critical vulnerability found → security ops halts all activity |
| `MINTER_ROLE` | Automated treasury/banking API |
| `COMPLIANCE_ROLE` | AML/KYC compliance officer |
| `DEFAULT_ADMIN_ROLE` | 3-of-5 executive multisig (Gnosis Safe) |

---

## Dependencies

- [OpenZeppelin Contracts v5](https://github.com/OpenZeppelin/openzeppelin-contracts) - battle-tested, audited base contracts
- Solidity `^0.8.20`

---

## Presented By

**Navil Rodrigues** - Blockchain Consultant  
*Blockchain Technology: From Hype to Reality - VCOE Guest Lecture*

---

## Disclaimer

This contract is written for **educational purposes**. It has not been professionally audited.  
**Do not deploy to mainnet with real funds without a full security audit.**