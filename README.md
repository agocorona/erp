erp
===
Notes: Because of the multiple declarations error for overloaded attribute names,
we have to create modules for each entity.
Also, the conventional support for an inheritance based generic class, such as
RequestType, Entity (where entity could be a data constructor) is not a recommended pattern, therefore we need to model entity as case expression when processing the entity.
We need a request log to manage log for the requests : time, ip etc.


## General running installation guide
 * cabal clean
 * cabal configure --enable-tests --user (i dont recall the need for this flag, its on haskellwiki somewhere)
 * cabal build
 * (there are no tests cases yet, so we do this) ./dist/build/tests/tests (If you see some output, things might be working)
## General Feature list
 * No SQL based implementation
 * Social anywhere
 * Websockets enabled

## Some more detail
 * Offline and realtime messaging: Users need to be able to send messages and all messages are persisted.
 * Each entity needs to be in draft/commit mode - Save/Save draft need to be default.
 * Realtime messaging needs to be context sensitive: for example if a user is working on a specific transaction that requires supervisory/cross functional approval, the system should set up an interface to discuss the particular transaction. All messages will be associated with the transaction for audit trail.
 * Approval workflow needs to be customizable.
 * Realtime data feed for currencies if needed. Usually currency transactions are end of day settlements. The system should be able to customize the sleep interval for querying currency rates.

## UI choices
 * Seaside or ScalaFX: My opinion is that ui has an oo bias and Smalltalk is a better solution. Need to investigate that.
 * For internal testing, wxPython seems to be a more suitable option. Though that is still debatable.
 * [Haxe](http://haxe.org)
 
## Coding standards (mostly borrowed from haskellwiki)
The server (ErpServer.hs) and the model (ErpModel.hs) are getting out of control. Needs a rewrite.
Naming of variables: this happens when we do a match for maybe and have to come
up with another set of readable names for each case. 


## Notes (discrepancies between the tryton and the current model):
  * The accounting method that simplifies computation of inventory and probably preferable is to manage products as batches
 is in this (link)[http://www.oldschoolvalue.com/blog/valuation-methods/fifo-lifo-average-inventory-valuation/#fifo-method]. To handle this additional requirement, the model deviates a bit from the tryton definition.
  * Account entity maintains a set of auto-complete tax types for a journal. This is better managed by the journal entitiy
  * The initial version was not using lenses, but it seems to be the right way to go,
    specially when we need to traverse/update tree-like structure: Account, Tax Code, Categories,
    UOM etc.
  * Error handling is using the ErpError across all constructors and this seems to be ok, because not doing this
  	seems to complicate the rest of the interface.

## Notes on testing the application
  * Current testing is quite brittle: the state machine is artificial: the issue is that we need a place
  	to terminate the tests so the thread can be canceled. Currently this is being done using some convention,
  	that needs to change everytime we add new messages. One way to test would be to send <i>n</i> messages,
  	expect n messages back and then complete state machine.

## References
 * [Tryton](http://doc.tryton.org/3.0/index.html)
 * [Accounting methods](http://en.wikipedia.org/wiki/FIFO_and_LIFO_accounting)
 * [Batch based computation](http://www.oldschoolvalue.com/blog/valuation-methods/fifo-lifo-average-inventory-valuation/#fifo-method)
