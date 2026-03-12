// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title  StablecoinUSD
 * @author Navil Rodrigues - Blockchain Consultant
 * @notice A regulated, USD-pegged ERC-20 stablecoin with full compliance controls.
 *
 * @dev    Architecture:
 *         ┌─────────────────────────────────────────────────────┐
 *         │  ERC-20 Base  │  AccessControl  │  Pausable         │
 *         └─────────────────────────────────────────────────────┘
 *                         ▼
 *         ┌─────────────────────────────────────────────────────┐
 *         │  Blacklist Mapping  │  Freeze Mapping               │
 *         └─────────────────────────────────────────────────────┘
 *
 *         Role hierarchy:
 *         DEFAULT_ADMIN_ROLE → grants / revokes all roles (use multisig in production)
 *         MINTER_ROLE        → mint() and burn()
 *         COMPLIANCE_ROLE    → blacklist(), unBlacklist(), freeze(), unFreeze()
 *         PAUSER_ROLE        → pause() and unpause()
 */
contract StablecoinUSD is ERC20, AccessControl, Pausable {

    // ─── ROLES ───────────────────────────────────────────────────────────────

    bytes32 public constant MINTER_ROLE     = keccak256("MINTER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant PAUSER_ROLE     = keccak256("PAUSER_ROLE");

    // ─── COMPLIANCE STATE ─────────────────────────────────────────────────────

    /// @notice Permanently blocked addresses (OFAC sanctions, court orders).
    mapping(address => bool) public blacklisted;

    /// @notice Temporarily locked accounts (AML investigations).
    mapping(address => bool) public frozen;

    // ─── EVENTS ───────────────────────────────────────────────────────────────

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event Frozen(address indexed account);
    event UnFrozen(address indexed account);

    // ─── CONSTRUCTOR ──────────────────────────────────────────────────────────

    /**
     * @param defaultAdmin  Address that receives DEFAULT_ADMIN_ROLE.
     *                      Use a multisig wallet (e.g. Gnosis Safe) in production.
     * @param minter        Address that receives MINTER_ROLE (backend API / treasury).
     * @param compliance    Address that receives COMPLIANCE_ROLE (compliance officer).
     * @param pauser        Address that receives PAUSER_ROLE (security ops).
     */
    constructor(
        address defaultAdmin,
        address minter,
        address compliance,
        address pauser
    ) ERC20("StablecoinUSD", "SUSD") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE,        minter);
        _grantRole(COMPLIANCE_ROLE,    compliance);
        _grantRole(PAUSER_ROLE,        pauser);
    }

    /**
     * @notice Returns the number of decimals used for SUSD.
     * @dev    Overrides the ERC20 default (18) so that 1 SUSD = 1e6 units.
     *         This makes on-chain amounts align with 6‑decimal stablecoins like USDC/USDT.
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // ─── MINTING & BURNING ────────────────────────────────────────────────────

    /**
     * @notice Create new SUSD tokens and send them to `to`.
     * @dev    Called by the backend when a verified fiat deposit is received.
     *         Real-world flow: user deposits USD → backend calls mint() → SUSD appears in wallet.
     *
     * @param to     Recipient wallet address.
     * @param amount Token amount (6 decimals - e.g. 1 SUSD = 1e6).
     *
     * Requirements:
     * - Caller must have MINTER_ROLE.
     * - Contract must not be paused.
     * - `to` must not be blacklisted.
     */
    function mint(address to, uint256 amount)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        require(!blacklisted[to], "StablecoinUSD: recipient is blacklisted");
        _mint(to, amount);
    }

    /**
     * @notice Destroy SUSD tokens from `from`.
     * @dev    Called by the backend when a redemption request is processed.
     *         Real-world flow: user redeems SUSD → backend calls burn() → USD sent via wire.
     *
     * @param from   Address whose tokens are burned.
     * @param amount Token amount to burn.
     *
     * Requirements:
     * - Caller must have MINTER_ROLE.
     * - Contract must not be paused.
     * - `from` must not be frozen (preserves evidence during investigations).
     */
    function burn(address from, uint256 amount)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
    {
        require(!frozen[from], "StablecoinUSD: account is frozen");
        _burn(from, amount);
    }

    // ─── COMPLIANCE CONTROLS ─────────────────────────────────────────────────

    /**
     * @notice Permanently block `account` from sending or receiving SUSD.
     * @dev    Use for OFAC SDN list entries and court-ordered asset freezes.
     *         Effect is immediate and irreversible until unBlacklist() is called.
     *
     * @param account  The address to blacklist.
     *
     * Requirements:
     * - Caller must have COMPLIANCE_ROLE.
     * - `account` must not already be blacklisted.
     */
    function blacklist(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(!blacklisted[account], "StablecoinUSD: already blacklisted");
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @notice Remove `account` from the blacklist.
     * @dev    Only use when a previous blacklisting was in error (false positive).
     *
     * @param account  The address to remove from the blacklist.
     *
     * Requirements:
     * - Caller must have COMPLIANCE_ROLE.
     * - `account` must currently be blacklisted.
     */
    function unBlacklist(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(blacklisted[account], "StablecoinUSD: not blacklisted");
        blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    /**
     * @notice Temporarily lock `account` - prevents all sends and receives.
     * @dev    Use during AML investigations. Reversible via unFreeze().
     *         Unlike blacklisting, frozen accounts retain ownership of their tokens.
     *
     * @param account  The address to freeze.
     *
     * Requirements:
     * - Caller must have COMPLIANCE_ROLE.
     * - `account` must not already be frozen.
     */
    function freeze(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(!frozen[account], "StablecoinUSD: already frozen");
        frozen[account] = true;
        emit Frozen(account);
    }

    /**
     * @notice Unfreeze `account`, restoring normal transfer capability.
     * @dev    Call this once an investigation is resolved with no adverse finding.
     *
     * @param account  The address to unfreeze.
     *
     * Requirements:
     * - Caller must have COMPLIANCE_ROLE.
     * - `account` must currently be frozen.
     */
    function unFreeze(address account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        require(frozen[account], "StablecoinUSD: not frozen");
        frozen[account] = false;
        emit UnFrozen(account);
    }

    // ─── PAUSE / UNPAUSE ──────────────────────────────────────────────────────

    /**
     * @notice Halt ALL token transfers across the entire contract.
     * @dev    Emergency circuit breaker. Use only during active security incidents.
     *         All mint, burn, and transfer calls will revert while paused.
     *
     * Requirements:
     * - Caller must have PAUSER_ROLE.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Resume normal contract operation after a pause.
     *
     * Requirements:
     * - Caller must have PAUSER_ROLE.
     * - Contract must currently be paused.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ─── INTERNAL HOOKS ───────────────────────────────────────────────────────

    /**
     * @dev Override ERC-20's internal `_update` hook to inject compliance checks.
     *      This runs automatically before EVERY mint, burn, and transfer.
     *
     *      Checks (in order):
     *      1. Contract is not paused            (enforced by Pausable)
     *      2. Sender is not blacklisted         (skipped for mint - `from` is address(0))
     *      3. Recipient is not blacklisted      (skipped for burn - `to` is address(0))
     *      4. Sender is not frozen              (skipped for mint)
     *      5. Recipient is not frozen           (skipped for burn)
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        // Enforce global pause state from Pausable.
        _requireNotPaused();

        // address(0) is used by ERC-20 for mint (from=0) and burn (to=0)
        if (from != address(0)) {
            require(!blacklisted[from], "StablecoinUSD: sender is blacklisted");
            require(!frozen[from],      "StablecoinUSD: sender account is frozen");
        }
        if (to != address(0)) {
            require(!blacklisted[to], "StablecoinUSD: recipient is blacklisted");
            require(!frozen[to],      "StablecoinUSD: recipient account is frozen");
        }
        super._update(from, to, amount);
    }

    /**
     * @dev Resolve multiple inheritance conflict for supportsInterface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
