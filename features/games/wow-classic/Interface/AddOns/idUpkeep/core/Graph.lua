local Logger = _G.idUpkeep_Logger
local Graph
do
  local _class_0
  local _base_0 = {
    key = "GraphNode",
    parent = nil,
    children = nil,
    fullName = "GraphNode",
    addChild = function(self, key, child)
      self.logger:debug("Graph:addChild " .. tostring(key))
      self.children[key] = child
    end,
    preorder = function(self)
      self.logger:debug("Graph:preorder " .. tostring(self.key))
      local traverse
      traverse = function(node)
        coroutine.yield(node)
        for _, child in pairs(node.children) do
          traverse(child)
        end
      end
      return coroutine.wrap(function()
        return traverse(self)
      end)
    end,
    postorder = function(self)
      self.logger:debug("Graph:postorder " .. tostring(self.key))
      local traverse
      traverse = function(node)
        for _, child in pairs(node.children) do
          traverse(child)
        end
        return coroutine.yield(node)
      end
      return coroutine.wrap(function()
        return traverse(self)
      end)
    end,
    isRoot = function(self)
      self.logger:debug("Graph:isRoot " .. tostring(self.key))
      return self.parent == nil
    end,
    isLeaf = function(self)
      self.logger:debug("Graph:isLeaf " .. tostring(self.key))
      return next(self.children) == nil
    end,
    getRoot = function(self)
      self.logger:debug("Graph:getRoot " .. tostring(self.key))
      local node = self
      while node.parent do
        node = node.parent
      end
      return node
    end,
    getDepth = function(self)
      self.logger:debug("Graph:getDepth " .. tostring(self.key))
      local depth = 0
      local node = self
      while node.parent do
        depth = depth + 1
        node = node.parent
      end
      return depth
    end,
    find = function(self, predicate)
      self.logger:debug("Graph:find " .. tostring(self.key))
      for node in self:preorder() do
        if predicate(node) then
          return node
        end
      end
      return nil
    end,
    findAll = function(self, predicate)
      self.logger:debug("Graph:findAll " .. tostring(self.key))
      local matches = { }
      for node in self:preorder() do
        if predicate(node) then
          table.insert(matches, node)
        end
      end
      return matches
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, parent, key)
      self.parent, self.key = parent, key
      self.logger = Logger:getInstance()
      self.logger:debug("Graph:new " .. tostring(self.key))
      self.children = { }
      if self.parent then
        self.parent:addChild(self.key, self)
        self.fullName = tostring(self.parent.fullName) .. "." .. tostring(self.key)
      else
        self.fullName = self.key
      end
    end,
    __base = _base_0,
    __name = "Graph"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Graph = _class_0
end
_G.idUpkeep_Graph = Graph
return Graph
