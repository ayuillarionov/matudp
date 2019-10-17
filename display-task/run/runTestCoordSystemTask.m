function runTestCoordSystemTask(cxt)

% initialize cxt = nd_lab_DisplayContext()
assert(nargin >= 1, ...
  'Usage: runTestCoordSystemTask(cxt) where cxt is the DisplayContext class you have created');

ns = NetworkShell(cxt);
ns.setTask(TestCoordSystemTask());
ns.run();