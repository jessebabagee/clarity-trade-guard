# TradeGuard

TradeGuard is a secure smart contract for managing trade agreements on the Stacks blockchain. It enables users to create, accept, and complete trade agreements with built-in escrow functionality and dispute resolution.

## Features

- Create trade agreements with specific terms and amounts
- Accept/reject trade proposals
- Escrow functionality to secure trades
- Comprehensive dispute resolution system
  - Parties can initiate disputes with detailed reasons
  - Contract owner can arbitrate and resolve disputes
  - Escrow funds can be returned to appropriate party
- Trade completion verification
- Status tracking throughout trade lifecycle

## Trade Statuses

- PENDING: Initial state when trade is created
- ACTIVE: Trade accepted, escrow deposited
- DISPUTED: Dispute initiated by either party
- RESOLVED: Dispute resolved by contract owner
- COMPLETED: Trade successfully completed

## Security

- Escrow funds held by contract during trade
- Only trade participants can initiate disputes
- Only contract owner can resolve disputes
- Clear state transitions and validation
