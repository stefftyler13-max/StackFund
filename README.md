

# sBTC-BioLedger -  Crowdfunding Smart Contract (Stacks Blockchain)

## Overview

This **Clarity smart contract** implements a decentralized **crowdfunding and voting platform** on the **Stacks blockchain**.
It allows users to create projects, invest STX tokens, and vote on them transparently.

Each project has validation rules for titles, descriptions, funding goals, and time limits.
Investments and votes are tracked on-chain to ensure full transparency and immutability.

---

## ⚙️ Features

* **Project creation** with strict title and description validation.
* **STX investments** with minimum and maximum limits.
* **Voting system** for community feedback and approval.
* **Automatic project lifecycle management** (active → expired).
* **Duplicate title protection** to prevent spam or confusion.
* **Comprehensive input validation and error handling.**

---

## 🧱 Contract Architecture

### Constants

| Constant                                            | Description                                          | Example     |
| --------------------------------------------------- | ---------------------------------------------------- | ----------- |
| `contract-owner`                                    | Address of the contract deployer                     | `tx-sender` |
| `min-investment`                                    | Minimum STX required to invest                       | `1 STX`     |
| `max-investment`                                    | Maximum STX allowed per project                      | `1000 STX`  |
| `voting-period`                                     | Number of blocks the project remains active (~1 day) | `u144`      |
| `min-vote-threshold`                                | Minimum number of votes to validate a proposal       | `u500000`   |
| `min-title-length` / `max-title-length`             | Title character limits                               | `4–50`      |
| `min-description-length` / `max-description-length` | Description character limits                         | `10–500`    |

---

### Error Codes

| Error                         | Code | Description                             |
| ----------------------------- | ---- | --------------------------------------- |
| `ERR-NOT-AUTHORIZED`          | 401  | Action requires ownership or permission |
| `ERR-INVALID-AMOUNT`          | 402  | Amount is below min or above max        |
| `ERR-PROJECT-NOT-FOUND`       | 404  | Invalid or missing project ID           |
| `ERR-PROJECT-EXPIRED`         | 405  | Project is past its end block           |
| `ERR-ALREADY-VOTED`           | 406  | Voter already cast a vote               |
| `ERR-INVALID-TITLE`           | 407  | Title failed validation rules           |
| `ERR-INVALID-DESCRIPTION`     | 408  | Description failed validation rules     |
| `ERR-INVALID-PROJECT-ID`      | 409  | ID does not reference a valid project   |
| `ERR-MAX-INVESTMENT-EXCEEDED` | 410  | Investment exceeds allowed cap          |
| `ERR-ZERO-AMOUNT`             | 411  | Amount is zero                          |
| `ERR-PROJECT-INACTIVE`        | 412  | Project is not currently active         |
| `ERR-DUPLICATE-TITLE`         | 413  | Project title already exists            |

---

## 🧮 Data Structures

### Global Variables

| Variable          | Type   | Description                         |
| ----------------- | ------ | ----------------------------------- |
| `project-counter` | `uint` | Auto-incremented project ID tracker |

---

### Maps

#### `projects`

Stores metadata for each project.

| Field            | Type                | Description                    |
| ---------------- | ------------------- | ------------------------------ |
| `creator`        | `principal`         | Project owner                  |
| `title`          | `string-ascii(50)`  | Project title                  |
| `description`    | `string-ascii(500)` | Project details                |
| `funding-goal`   | `uint`              | Required STX funding           |
| `current-amount` | `uint`              | Total STX raised so far        |
| `status`         | `string-ascii(20)`  | `"active"`, `"expired"`, etc.  |
| `end-block`      | `uint`              | Block height when project ends |
| `creation-block` | `uint`              | Block when project was created |
| `last-updated`   | `uint`              | Last modification block height |

---

#### `project-titles`

Prevents duplicate project titles.

| Key     | Value              | Description                         |
| ------- | ------------------ | ----------------------------------- |
| `title` | `{ exists: bool }` | Marks whether title is already used |

---

#### `investments`

Tracks STX investments per user and project.

| Field          | Type        | Description                     |
| -------------- | ----------- | ------------------------------- |
| `project-id`   | `uint`      | Target project                  |
| `investor`     | `principal` | Investor wallet address         |
| `amount`       | `uint`      | Total STX invested by this user |
| `timestamp`    | `uint`      | When investment was made        |
| `last-updated` | `uint`      | Last time investor contributed  |

---

#### `votes`

Records community votes for each project.

| Field        | Type        | Description                           |
| ------------ | ----------- | ------------------------------------- |
| `project-id` | `uint`      | Project being voted on                |
| `voter`      | `principal` | Voter address                         |
| `vote`       | `bool`      | True for positive, false for negative |
| `timestamp`  | `uint`      | Vote timestamp                        |

---

#### `vote-counts`

Stores aggregated vote data.

| Field            | Type   | Description              |
| ---------------- | ------ | ------------------------ |
| `total-votes`    | `uint` | Number of all votes      |
| `positive-votes` | `uint` | Upvotes                  |
| `negative-votes` | `uint` | Downvotes                |
| `last-updated`   | `uint` | Timestamp of last update |

---

## 🔒 Validation Logic

### Title Validation

* Must be **4–50 characters**.
* Must not be empty or previously used.

### Description Validation

* Must be **10–500 characters**.
* Must not be empty.

### Project Validation

* Project ID must be between `1` and `project-counter`.
* Must exist and be active (status `"active"`).
* Must not have expired (`block-height < end-block`).

### Investment Validation

* Amount must be within `[min-investment, max-investment]`.
* Project’s total investment cannot exceed `max-investment`.

---

## 📜 Public Functions

### 1. `create-project`

```clarity
(define-public (create-project 
    (title (string-ascii 50)) 
    (description (string-ascii 500))
    (funding-goal uint))
```

**Purpose:**
Create a new crowdfunding project.

**Validations:**

* Title and description lengths checked.
* Funding goal must meet min/max thresholds.
* Title must not already exist.

**On success:**

* Saves project to the `projects` map.
* Registers title in `project-titles`.
* Initializes vote count in `vote-counts`.
* Returns `(ok project-id)`.

---

### 2. `invest`

```clarity
(define-public (invest (project-id uint) (amount uint))
```

**Purpose:**
Allows a user to invest STX in an active project.

**Validations:**

* Project ID must exist.
* Project must be active and not expired.
* Amount must be valid and within limits.
* Total investment must not exceed cap.

**Process:**

* Transfers STX from investor → contract.
* Updates project’s `current-amount`.
* Updates or creates an `investment` record.

**Returns:** `(ok true)` on success.

---

## 📈 Future Extensions

This contract is designed for extensibility. Possible additions:

* **Vote casting and aggregation** (extend voting system).
* **Automatic project finalization** after funding goal or expiry.
* **Refund mechanism** for failed projects.
* **Reward distribution** for successful projects.
* **Admin moderation** for project approval or removal.

---

## 🧪 Testing Suggestions

Recommended test cases:

| Category             | Test Case                                                    |
| -------------------- | ------------------------------------------------------------ |
| **Project Creation** | Rejects short titles, long titles, or duplicates             |
|                      | Rejects short or empty descriptions                          |
|                      | Rejects invalid funding goals                                |
| **Investment**       | Fails if project expired or inactive                         |
|                      | Fails if amount < min or > max                               |
|                      | Correctly updates project total                              |
|                      | Prevents overfunding beyond `max-investment`                 |
| **Voting**           | (Future) Ensures one vote per user per project               |
| **Edge Cases**       | Handles zero amounts, invalid IDs, and non-existent projects |

---

## 🧾 License

This contract is released under the **MIT License**.
You’re free to use, modify, and distribute with attribution.

---
