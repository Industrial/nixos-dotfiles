local Logger = _G.idUpkeep_Logger
local String = _G.idUpkeep_String
local Table = _G.idUpkeep_Table
local VersionInfo = _G.idUpkeep_VersionInfo
local Database
do
  local _class_0
  local _base_0 = {
    reattachSavedVariables = function(self)
      local name = self.savedVariablesName
      if not (_G[name]) then
        self.logger:info("Creating new database: " .. tostring(name))
        _G[name] = Table.deep_copy(self.defaultStructure)
      end
      self.db = _G[name]
      self:_update_metadata()
      self.db._meta = self.db._meta or { }
      self.db.account = self.db.account or { }
      self.db.character = self.db.character or { }
      self:ensureCharacterContext()
      return self.db
    end,
    _setup_character_context = function(self)
      self.logger:debug("Database:_setup_character_context")
      local unitName = _G.UnitName
      local getRealmName = _G.GetRealmName
      if not (unitName and getRealmName) then
        return 
      end
      local charName, surname = unitName("player")
      local realmName = getRealmName()
      if charName and realmName and charName ~= "" and realmName ~= "" then
        self.characterKey = tostring(realmName) .. "." .. tostring(charName)
        local bucket = self.db.character[self.characterKey] or { }
        self.db.character[self.characterKey] = bucket
        if type(surname) == "string" and surname ~= "" then
          bucket._surname = surname
        end
        return self.logger:debug("Character context: " .. tostring(self.characterKey))
      end
    end,
    ensureCharacterContext = function(self)
      self:_setup_character_context()
      if not (self.characterKey) then
        return false
      end
      self:_migrate_character_orphans()
      return true
    end,
    _migrate_character_orphans = function(self)
      if not (self.characterKey and self.db.character) then
        return 
      end
      local bucket = self.db.character[self.characterKey]
      if not (bucket) then
        return 
      end
      if self.db.character.enable ~= nil then
        if bucket.enable == nil then
          bucket.enable = self.db.character.enable
        end
        self.db.character.enable = nil
        self.logger:debug("Migrated character.enable into " .. tostring(self.characterKey))
      end
      local toClear = { }
      for key, val in pairs(self.db.character) do
        local _continue_0 = false
        repeat
          if key == self.characterKey then
            _continue_0 = true
            break
          end
          if type(val) ~= "table" then
            _continue_0 = true
            break
          end
          if string.find(key, ".", 1, true) then
            _continue_0 = true
            break
          end
          if bucket[key] == nil then
            bucket[key] = val
            self.logger:debug("Migrated orphan character." .. tostring(key) .. " into " .. tostring(self.characterKey))
          end
          table.insert(toClear, key)
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      for _index_0 = 1, #toClear do
        local key = toClear[_index_0]
        self.db.character[key] = nil
      end
    end,
    _update_metadata = function(self)
      self.logger:debug("Database:_update_metadata")
      self.db._meta = self.db._meta or { }
      self.db._meta.last_updated = (_G.time and _G.time()) or 0
      self.db._meta.schema_version = self.db._meta.schema_version or self.schemaVersion
    end,
    get_schema_version = function(self)
      self.logger:debug("Database:get_schema_version")
      return self.db._meta and self.db._meta.schema_version or 0
    end,
    needs_migration = function(self)
      self.logger:debug("Database:needs_migration")
      local current = self:get_schema_version()
      return current < self.schemaVersion
    end,
    set_schema_version = function(self, version)
      self.logger:debug("Database:set_schema_version")
      self.schemaVersion = version
    end,
    register_migration = function(self, fromVersion, toVersion, migrationFunc, description)
      self.logger:debug("Database:register_migration")
      local migrationKey = tostring(fromVersion) .. "_to_" .. tostring(toVersion)
      self.migrations[migrationKey] = {
        func = migrationFunc,
        description = description or "Migration from v" .. tostring(fromVersion) .. " to v" .. tostring(toVersion),
        fromVersion = fromVersion,
        toVersion = toVersion
      }
      return self.logger:debug("Registered migration: " .. tostring(self.migrations[migrationKey].description))
    end,
    run_migrations = function(self)
      self.logger:debug("Database:run_migrations")
      if not self:needs_migration() then
        return {
          status = "up_to_date",
          migrations_run = 0
        }
      end
      local currentVersion = self:get_schema_version()
      local targetVersion = self.schemaVersion
      local results = {
        status = "success",
        migrations_run = 0,
        from_version = currentVersion,
        to_version = targetVersion,
        completed = { },
        failed = { }
      }
      self.logger:info("Running migrations from v" .. tostring(currentVersion) .. " to v" .. tostring(targetVersion))
      for version = currentVersion + 1, targetVersion do
        local migrationKey = tostring(version - 1) .. "_to_" .. tostring(version)
        if self.migrations[migrationKey] then
          local migration = self.migrations[migrationKey]
          self.logger:info("Applying: " .. tostring(migration.description))
          local success, errorMsg = pcall(migration.func, self.db)
          if success then
            self.db._meta.schema_version = version
            results.migrations_run = results.migrations_run + 1
            table.insert(results.completed, migration.description)
            self.logger:info("Migration successful: v" .. tostring(version))
          else
            table.insert(results.failed, {
              version = version,
              description = migration.description,
              error = errorMsg
            })
            results.status = "failed"
            self.logger:error("Migration failed: " .. tostring(errorMsg))
            break
          end
        else
          self.db._meta.schema_version = version
          results.migrations_run = results.migrations_run + 1
          self.logger:warn("No migration registered for v" .. tostring(version) .. ", updating version only")
        end
      end
      self:_update_metadata()
      return results
    end,
    get = function(self, path, defaultValue)
      if not path then
        self.logger:debug("Database:get (root)")
        return self.db
      end
      if path:match("^character") then
        self:ensureCharacterContext()
      end
      local parts = self:_expand_character_parts(path)
      local current = self.db
      for _index_0 = 1, #parts do
        local part = parts[_index_0]
        if type(current) == "table" and current[part] ~= nil then
          current = current[part]
        else
          self.logger:debug("Database:get " .. tostring(path) .. " = " .. tostring(tostring(defaultValue)) .. " (default)")
          return defaultValue
        end
      end
      self.logger:debug("Database:get " .. tostring(path) .. " = " .. tostring(tostring(current)))
      return current
    end,
    set = function(self, path, value)
      self.logger:debug("Database:set")
      if not path then
        return false
      end
      if path:match("^character") then
        self:ensureCharacterContext()
      end
      local parts = self:_expand_character_parts(path)
      if #parts == 0 then
        return false
      end
      local current = self.db
      for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
          current[part] = { }
        end
        current = current[part]
      end
      current[parts[#parts]] = value
      self:_update_metadata()
      return true
    end,
    _expand_character_parts = function(self, path)
      local parts
      do
        local _accum_0 = { }
        local _len_0 = 1
        for part in string.gmatch(path, "[^%.]+") do
          _accum_0[_len_0] = part
          _len_0 = _len_0 + 1
        end
        parts = _accum_0
      end
      if parts[1] == "character" and self.characterKey then
        local newParts = {
          "character",
          self.characterKey
        }
        for i = 2, #parts do
          table.insert(newParts, parts[i])
        end
        return newParts
      end
      return parts
    end,
    exists = function(self, path)
      self.logger:debug("Database:exists")
      return self:get(path, nil) ~= nil
    end,
    delete = function(self, path)
      self.logger:debug("Database:delete")
      return self:set(path, nil)
    end,
    get_with_fallback = function(self, charPath, accountPath, defaultValue)
      self.logger:debug("Database:get_with_fallback")
      local charValue = self:get("character." .. tostring(charPath))
      if charValue ~= nil then
        return charValue
      end
      if accountPath then
        local accountValue = self:get("account." .. tostring(accountPath))
        if accountValue ~= nil then
          return accountValue
        end
      end
      return defaultValue
    end,
    merge_defaults = function(self, defaults, target)
      self.logger:debug("Database:merge_defaults")
      local targetTable
      if target then
        targetTable = self:get(target, { })
      else
        targetTable = self.db
      end
      Table.deep_merge(defaults, targetTable, false)
      if target then
        self:set(target, targetTable)
      end
      return self:_update_metadata()
    end,
    get_metadata = function(self)
      self.logger:debug("Database:get_metadata")
      return self.db._meta or { }
    end,
    get_info = function(self)
      self.logger:debug("Database:get_info")
      return {
        savedVariablesName = self.savedVariablesName,
        schemaVersion = self.schemaVersion,
        currentVersion = self:get_schema_version(),
        needsMigration = self:needs_migration(),
        characterKey = self.characterKey,
        hasCharacterData = self.characterKey and self:exists("character") or false
      }
    end,
    validate = function(self)
      self.logger:debug("Database:validate")
      if type(self.db) ~= "table" then
        return false, "Database is not a table"
      end
      if not self.db._meta then
        return false, "Missing metadata section"
      end
      if not self.db.account then
        return false, "Missing account section"
      end
      if not self.db.character then
        return false, "Missing character section"
      end
      return true, nil
    end,
    export = function(self, includeCharacterData)
      if includeCharacterData == nil then
        includeCharacterData = false
      end
      self.logger:debug("Database:export")
      local exportData = {
        _meta = self:get_metadata(),
        account = self:get("account", { }),
        exported_at = time(),
        exported_by = self.characterKey
      }
      if includeCharacterData then
        exportData.character = self:get("character", { })
      end
      return exportData
    end,
    mergeDefaults = function(self, dest, defaults)
      local isDebugBuild
      if VersionInfo and VersionInfo.getInstance then
        isDebugBuild = VersionInfo:getInstance():IsDebugBuild()
      else
        local _scrap_0 = self.logger.debugEnabled
      end
      if isDebugBuild then
        self.logger:debug("Database:mergeDefaults (verbose logging enabled)")
        local merge_with_logging
        merge_with_logging = function(d, def, path)
          if path == nil then
            path = ""
          end
          for k, v in pairs(def) do
            local currentPath
            if #path > 0 then
              currentPath = tostring(path) .. "." .. tostring(k)
            else
              currentPath = k
            end
            if type(v) == "table" then
              d[k] = d[k] or { }
              self.logger:debug("Merging defaults for table field:", currentPath)
              merge_with_logging(d[k], v, currentPath)
            elseif d[k] == nil then
              self.logger:debug("Setting default value for field:", currentPath, v)
              d[k] = v
            end
          end
          return d
        end
        merge_with_logging(dest, defaults)
      else
        Table.deep_merge(defaults, dest, false)
      end
      return dest
    end,
    get_migration_status = function(self)
      self.logger:debug("Database:get_migration_status")
      local currentVersion = self:get_schema_version()
      local targetVersion = self.schemaVersion
      return {
        current_version = currentVersion,
        target_version = targetVersion,
        needs_migration = currentVersion < targetVersion,
        is_future_version = currentVersion > targetVersion,
        registered_migrations = (function()
          local _accum_0 = { }
          local _len_0 = 1
          for key, migration in pairs(self.migrations) do
            _accum_0[_len_0] = {
              key = key,
              description = migration.description,
              from = migration.fromVersion,
              to = migration.toVersion
            }
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)()
      }
    end,
    _migration_deep_merge = function(self, source, target, overwrite)
      if overwrite == nil then
        overwrite = false
      end
      self.logger:debug("Database:_migration_deep_merge")
      return Table.deep_merge(source, target, overwrite)
    end,
    create_default_migration = function(self, defaults, targetPath)
      self.logger:debug("Database:create_default_migration")
      return function(db)
        return self:migration_merge_defaults(db, defaults, targetPath)
      end
    end,
    create_rename_migration = function(self, renames)
      self.logger:debug("Database:create_rename_migration")
      return function(db)
        for oldPath, newPath in pairs(renames) do
          local success = self:migration_rename_field(db, oldPath, newPath)
          if not success then
            self.logger:warn("Failed to rename " .. tostring(oldPath) .. " to " .. tostring(newPath))
          end
        end
      end
    end,
    validate_migration_chain = function(self)
      self.logger:debug("Database:validate_migration_chain")
      local currentVersion = self:get_schema_version()
      local targetVersion = self.schemaVersion
      local missing = { }
      for version = currentVersion + 1, targetVersion do
        local migrationKey = tostring(version - 1) .. "_to_" .. tostring(version)
        if not self.migrations[migrationKey] then
          table.insert(missing, "v" .. tostring(version - 1) .. " to v" .. tostring(version))
        end
      end
      return #missing == 0, missing
    end,
    validation_rules = { },
    validation_enabled = true,
    set_validation_enabled = function(self, enabled)
      self.logger:debug("Database:set_validation_enabled")
      self.validation_enabled = enabled
    end,
    register_validation_rule = function(self, path, rule, description)
      self.logger:debug("Database:register_validation_rule")
      self.validation_rules[path] = {
        rule = rule,
        description = description or "Custom validation rule for " .. tostring(path),
        registered_at = time()
      }
      return self.logger:debug("Registered validation rule for path: " .. tostring(path))
    end,
    remove_validation_rule = function(self, path)
      self.logger:debug("Database:remove_validation_rule")
      self.validation_rules[path] = nil
    end,
    validate_value = function(self, path, value)
      self.logger:debug("Database:validate_value")
      if not self.validation_enabled then
        return true, nil
      end
      if self.validation_rules[path] then
        return self:_apply_validation_rule(self.validation_rules[path], value, path)
      end
      for rulePath, ruleInfo in pairs(self.validation_rules) do
        if self:_path_matches_pattern(path, rulePath) then
          local success, error = self:_apply_validation_rule(ruleInfo, value, path)
          if not success then
            return false, error
          end
        end
      end
      return true, nil
    end,
    _apply_validation_rule = function(self, ruleInfo, value, path)
      self.logger:debug("Database:_apply_validation_rule")
      local rule = ruleInfo.rule
      if type(rule) == "function" then
        local success, result = pcall(rule, value, path)
        if not success then
          return false, "Validation function error: " .. tostring(result)
        end
        if type(result) == "boolean" then
          return result, (function()
            if result then
              return nil
            else
              return "Validation failed for " .. tostring(path)
            end
          end)()
        elseif type(result) == "table" and result.valid ~= nil then
          return result.valid, result.error or ((function()
            if result.valid then
              return nil
            else
              return "Validation failed"
            end
          end)())
        else
          return false, "Invalid validation function return type"
        end
      elseif type(rule) == "table" then
        return self:_validate_with_rule_object(rule, value, path)
      end
      return false, "Invalid rule type"
    end,
    _validate_with_rule_object = function(self, rule, value, path)
      self.logger:debug("Database:_validate_with_rule_object")
      if rule.type then
        if type(value) ~= rule.type then
          return false, "Expected " .. tostring(rule.type) .. ", got " .. tostring(type(value)) .. " for " .. tostring(path)
        end
      end
      if rule.required and value == nil then
        return false, "Required field " .. tostring(path) .. " is nil"
      end
      if not rule.allow_nil and value == nil then
        return false, "Field " .. tostring(path) .. " cannot be nil"
      end
      if value == nil then
        return true, nil
      end
      if rule.type == "number" or type(value) == "number" then
        if rule.min and value < rule.min then
          return false, "Value " .. tostring(value) .. " is below minimum " .. tostring(rule.min) .. " for " .. tostring(path)
        end
        if rule.max and value > rule.max then
          return false, "Value " .. tostring(value) .. " is above maximum " .. tostring(rule.max) .. " for " .. tostring(path)
        end
        if rule.integer and math.floor(value) ~= value then
          return false, "Value " .. tostring(value) .. " must be an integer for " .. tostring(path)
        end
      end
      if rule.type == "string" or type(value) == "string" then
        if rule.min_length and string.len(value) < rule.min_length then
          return false, "String too short (" .. tostring(string.len(value)) .. " < " .. tostring(rule.min_length) .. ") for " .. tostring(path)
        end
        if rule.max_length and string.len(value) > rule.max_length then
          return false, "String too long (" .. tostring(string.len(value)) .. " > " .. tostring(rule.max_length) .. ") for " .. tostring(path)
        end
        if rule.pattern and not string.match(value, rule.pattern) then
          return false, "String does not match pattern for " .. tostring(path)
        end
      end
      if rule.type == "table" or type(value) == "table" then
        if rule.min_items and #value < rule.min_items then
          return false, "Table has too few items (" .. tostring(#value) .. " < " .. tostring(rule.min_items) .. ") for " .. tostring(path)
        end
        if rule.max_items and #value > rule.max_items then
          return false, "Table has too many items (" .. tostring(#value) .. " > " .. tostring(rule.max_items) .. ") for " .. tostring(path)
        end
      end
      if rule.enum then
        local valid = false
        for _, allowed in ipairs(rule.enum) do
          if value == allowed then
            valid = true
            break
          end
        end
        if not valid then
          return false, "Value " .. tostring(value) .. " not in allowed values for " .. tostring(path)
        end
      end
      if rule.validator then
        local success, result = pcall(rule.validator, value, path)
        if not success then
          return false, "Custom validator error: " .. tostring(result)
        end
        if not result then
          return false, "Custom validation failed for " .. tostring(path)
        end
      end
      return true, nil
    end,
    _path_matches_pattern = function(self, path, pattern)
      self.logger:debug("Database:_path_matches_pattern")
      return String.match_path_pattern(path, pattern)
    end,
    set_validated = function(self, path, value, skipValidation)
      if skipValidation == nil then
        skipValidation = false
      end
      self.logger:debug("Database:set_validated")
      if not skipValidation and self.validation_enabled then
        local valid, error = self:validate_value(path, value)
        if not valid then
          Logger:warn("Validation failed for " .. tostring(path) .. ": " .. tostring(error))
          return false, error
        end
      end
      local success = self:set(path, value)
      return success, (function()
        if success then
          return nil
        else
          return "Failed to set value"
        end
      end)()
    end,
    validate_all = function(self)
      self.logger:debug("Database:validate_all")
      local results = {
        valid = true,
        errors = { },
        warnings = { },
        checked_paths = 0
      }
      self:_validate_recursive(self.db, "", results)
      results.valid = #results.errors == 0
      return results
    end,
    _validate_recursive = function(self, data, basePath, results)
      self.logger:debug("Database:_validate_recursive")
      if type(data) ~= "table" then
        return 
      end
      for key, value in pairs(data) do
        local path
        if basePath == "" then
          path = key
        else
          path = tostring(basePath) .. "." .. tostring(key)
        end
        results.checked_paths = results.checked_paths + 1
        local valid, error = self:validate_value(path, value)
        if not valid then
          table.insert(results.errors, {
            path = path,
            error = error
          })
        end
        if type(value) == "table" then
          self:_validate_recursive(value, path, results)
        end
      end
    end,
    Get = function(self, path, defaultValue)
      self.logger:debug("Database:Get (alias)")
      return self:get(path, defaultValue)
    end,
    Set = function(self, path, value)
      self.logger:debug("Database:Set (alias)")
      return self:set(path, value)
    end,
    Exists = function(self, path)
      self.logger:debug("Database:Exists (alias)")
      return self:exists(path)
    end,
    Delete = function(self, path)
      self.logger:debug("Database:Delete (alias)")
      return self:delete(path)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, savedVariablesName, defaultStructure, initialSchemaVersion)
      if initialSchemaVersion == nil then
        initialSchemaVersion = 1
      end
      self.logger = Logger:getInstance()
      self.logger:debug("Database:new")
      self.savedVariablesName = savedVariablesName
      self.schemaVersion = initialSchemaVersion
      self.migrations = { }
      local now = (_G.time and _G.time()) or 0
      self.defaultStructure = defaultStructure or {
        _meta = {
          schema_version = self.schemaVersion,
          created_at = now,
          last_updated = now
        },
        account = { },
        character = { }
      }
      if not _G[self.savedVariablesName] then
        self.logger:info("Creating new database: " .. tostring(self.savedVariablesName))
        _G[self.savedVariablesName] = Table.deep_copy(self.defaultStructure)
      end
      self:reattachSavedVariables()
      return self.logger:debug("Database initialized: " .. tostring(self.savedVariablesName))
    end,
    __base = _base_0,
    __name = "Database"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.migration_rename_field = function(_, db, oldPath, newPath)
    self.logger:debug("Database:migration_rename_field")
    local oldParts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(oldPath, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      oldParts = _accum_0
    end
    local current = db
    for i = 1, #oldParts - 1 do
      local part = oldParts[i]
      if type(current[part]) ~= "table" then
        return false
      end
      current = current[part]
    end
    local oldField = oldParts[#oldParts]
    if current[oldField] == nil then
      return false
    end
    local value = current[oldField]
    local newParts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(newPath, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      newParts = _accum_0
    end
    local target = db
    for i = 1, #newParts - 1 do
      local part = newParts[i]
      target[part] = target[part] or { }
      target = target[part]
    end
    local newField = newParts[#newParts]
    target[newField] = value
    current[oldField] = nil
    return true
  end
  self.migration_add_field = function(_, db, path, defaultValue)
    self.logger:debug("Database:migration_add_field")
    local parts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(path, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      parts = _accum_0
    end
    local current = db
    for i = 1, #parts - 1 do
      local part = parts[i]
      current[part] = current[part] or { }
      current = current[part]
    end
    local field = parts[#parts]
    if current[field] == nil then
      current[field] = defaultValue
      return true
    end
    return false
  end
  self.migration_remove_field = function(_, db, path)
    self.logger:debug("Database:migration_remove_field")
    local parts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(path, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      parts = _accum_0
    end
    local current = db
    for i = 1, #parts - 1 do
      local part = parts[i]
      if type(current[part]) ~= "table" then
        return false
      end
      current = current[part]
    end
    local field = parts[#parts]
    if current[field] ~= nil then
      current[field] = nil
      return true
    end
    return false
  end
  self.migration_transform_field = function(_, db, path, transformFunc)
    self.logger:debug("Database:migration_transform_field")
    local parts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(path, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      parts = _accum_0
    end
    local current = db
    for i = 1, #parts - 1 do
      local part = parts[i]
      if type(current[part]) ~= "table" then
        return false
      end
      current = current[part]
    end
    local field = parts[#parts]
    if current[field] ~= nil then
      local success, newValue = pcall(transformFunc, current[field])
      if success then
        current[field] = newValue
        return true
      end
    end
    return false
  end
  self.migration_move_data = function(_, db, fromPath, toPath, removeOriginal)
    if removeOriginal == nil then
      removeOriginal = true
    end
    self.logger:debug("Database:migration_move_data")
    local fromParts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(fromPath, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      fromParts = _accum_0
    end
    local current = db
    for i = 1, #fromParts - 1 do
      local part = fromParts[i]
      if type(current[part]) ~= "table" then
        return false
      end
      current = current[part]
    end
    local fromField = fromParts[#fromParts]
    if current[fromField] == nil then
      return false
    end
    local value = current[fromField]
    local toParts
    do
      local _accum_0 = { }
      local _len_0 = 1
      for part in string.gmatch(toPath, "[^%.]+") do
        _accum_0[_len_0] = part
        _len_0 = _len_0 + 1
      end
      toParts = _accum_0
    end
    local target = db
    for i = 1, #toParts - 1 do
      local part = toParts[i]
      target[part] = target[part] or { }
      target = target[part]
    end
    local toField = toParts[#toParts]
    target[toField] = value
    if removeOriginal then
      current[fromField] = nil
    end
    return true
  end
  self.migration_merge_defaults = function(_, db, defaults, targetPath)
    self.logger:debug("Database:migration_merge_defaults")
    local target = db
    if targetPath then
      local parts
      do
        local _accum_0 = { }
        local _len_0 = 1
        for part in string.gmatch(targetPath, "[^%.]+") do
          _accum_0[_len_0] = part
          _len_0 = _len_0 + 1
        end
        parts = _accum_0
      end
      for _index_0 = 1, #parts do
        local part = parts[_index_0]
        if type(target[part]) ~= "table" then
          target[part] = { }
        end
        target = target[part]
      end
    end
    self:_migration_deep_merge(defaults, target, false)
    return true
  end
  self.create_validation_rules = function(_)
    self.logger:debug("Database:create_validation_rules")
    return {
      string = function(minLen, maxLen)
        return {
          type = "string",
          min_length = minLen,
          max_length = maxLen
        }
      end,
      number = function(min, max)
        return {
          type = "number",
          min = min,
          max = max
        }
      end,
      integer = function(min, max)
        return {
          type = "number",
          min = min,
          max = max,
          integer = true
        }
      end,
      boolean = function()
        return {
          type = "boolean"
        }
      end,
      table = function(minItems, maxItems)
        return {
          type = "table",
          min_items = minItems,
          max_items = maxItems
        }
      end,
      required = function(baseRule)
        local rule = baseRule or { }
        rule.required = true
        return rule
      end,
      enum = function(values)
        return {
          enum = values
        }
      end,
      pattern = function(regex)
        return {
          type = "string",
          pattern = regex
        }
      end,
      optional_string = function(minLen, maxLen)
        return {
          type = "string",
          min_length = minLen,
          max_length = maxLen,
          allow_nil = true
        }
      end,
      positive_number = function()
        return {
          type = "number",
          min = 0
        }
      end,
      positive_integer = function()
        return {
          type = "number",
          min = 0,
          integer = true
        }
      end
    }
  end
  Database = _class_0
end
_G.idUpkeep_Database = Database
return Database
