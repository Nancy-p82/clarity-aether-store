import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can list a new product",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const block = chain.mineBlock([
      Tx.contractCall('aether-store', 'list-product', [
        types.ascii("Test Product"),
        types.uint(1000000),
        types.uint(10),
        types.ascii("Test Description"),
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
    
    const response = chain.callReadOnlyFn(
      'aether-store',
      'get-product',
      [types.uint(1)],
      deployer.address
    );
    
    const product = response.result.expectSome().expectTuple();
    assertEquals(product.name, "Test Product");
    assertEquals(product.price, "1000000");
    assertEquals(product.quantity, "10");
  }
});

Clarinet.test({
  name: "Can purchase a product",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const buyer = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('aether-store', 'list-product', [
        types.ascii("Test Product"),
        types.uint(1000000),
        types.uint(10),
        types.ascii("Test Description"),
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    
    block = chain.mineBlock([
      Tx.contractCall('aether-store', 'purchase-product', [
        types.uint(1),
        types.principal(buyer.address)
      ], buyer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    const response = chain.callReadOnlyFn(
      'aether-store',
      'get-product',
      [types.uint(1)],
      deployer.address
    );
    
    const product = response.result.expectSome().expectTuple();
    assertEquals(product.quantity, "9");
  }
});

Clarinet.test({
  name: "Can leave a review",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const buyer = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('aether-store', 'list-product', [
        types.ascii("Test Product"),
        types.uint(1000000),
        types.uint(10),
        types.ascii("Test Description"),
        types.principal(deployer.address)
      ], deployer.address)
    ]);
    
    block = chain.mineBlock([
      Tx.contractCall('aether-store', 'leave-review', [
        types.uint(1),
        types.uint(5),
        types.ascii("Great product!")
      ], buyer.address)
    ]);
    
    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectBool(true);
    
    const response = chain.callReadOnlyFn(
      'aether-store',
      'get-review',
      [types.uint(1), types.principal(buyer.address)],
      deployer.address
    );
    
    const review = response.result.expectSome().expectTuple();
    assertEquals(review.rating, "5");
    assertEquals(review.comment, "Great product!");
  }
});
