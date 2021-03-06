The everything list
===

### Dev env setup

#### Nix package manager
	There is a startup .nix file, need to get the versions the same 
	as the cabal file. How to do that?

#### Chef (we probably need both chef and nix because liferay is probably chef friendly)
	Chef and nix seem to be competing for the same space. Though nix is probably more 
	functional therefore suitable for the current application.
#### Install ruby -- Done

. Setup java -- Done
. Setup maven -- Done
. Setup ant -- Done
. Setup scala -- Done
. Setup spray -- TBD
. Setup liferay : 6.2 branch and master.
. Gridgain 
. Gridgain enable liferay installation
. Postgres
. Eclipse -- Done
. Tmux -- Done
. Setup liferay for automated tests
. Implement security cookbook recepies
. Install OAUTH provider
. Grails 2.2.4
. Sublime haskell -- Done 
. Sublime git -- Done
. Enable erp CI using travis
. Enable osgi for liferay 
. Enable osgi in general?
. Install haxe ?? or should it be spray?
. Install and get familiar with xmonad -- This can be sort of tmux?
. Get better at using the ghci: how to look at the type signature of methods not exposed in the module
. As a corollary, improve the interface in the current application. Keep a lot of things private
. Really really add features to the model. We need to start processing messages for the model.
. Closure compiler - understand code -- A bit..but that is a lot of code.

### Dev tasks (should probably go in the readme.md)

. Add ErpHelper module to handle imports for the project in one place
. Replace JSON messages (a bit clunky) with show instances for each data constructor. Make this configurable
  to be able to switch it between raw messages and data messages.
. Checkin a reference test output that can be reliable across different runs - this would most likely 
	need a split between the server and the client threads and only single threaded tests to prevent 
	interleaving of output?? -- The principle being that if the output has changed, then there is a either
	a bug fix so the change should equal the fix or there is a new feature. In all other circumstances,
	the output needs to be identical across all tests
. Move the current thead into snap
. Implement product rest services.
. Make lenses for manipulating the model.
. RabbitMQ or ZeroMQ for messaging infrastructure support. 
. Distributed haskell for distributing the application.
