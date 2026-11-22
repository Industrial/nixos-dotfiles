


















local _, ns = ...






ns.FOREVER_INSTANCES = {
    { id = 33, n = "Shadowfang Keep", raid = false, players = 10, m = 1421, x = 0.4472, y = 0.6777, ci = 0, wx = -231, wy = 1572, cm = 1415, cx = 0.4099, cy = 0.328 },
    { id = 34, n = "Stormwind Stockade", raid = false, players = 10, m = 1453, x = 0.5035, y = 0.6618, ci = 0, wx = -8762, wy = 848, cm = 1415, cx = 0.4305, cy = 0.6916 },
    { id = 36, n = "Deadmines", raid = false, players = 10, m = 1436, x = 0.3816, y = 0.7748, ci = 0, wx = -11208, wy = 1681, cm = 1415, cx = 0.4068, cy = 0.7958 },
    { id = 43, n = "Wailing Caverns", raid = false, players = 10, m = 1413, x = 0.4599, y = 0.3627, ci = 1, wx = -838, wy = -2037, dx = 0.4769, dy = 0.3498, cm = 1414, cx = 0.5191, cy = 0.5559 },
    { id = 47, n = "Razorfen Kraul", raid = false, players = 10, m = 1413, x = 0.4227, y = 0.8987, ci = 1, wx = -4459, wy = -1660, cm = 1414, cx = 0.5089, cy = 0.7035 },
    { id = 48, n = "Blackfathom Deeps", raid = false, players = 10, m = 1440, x = 0.165, y = 0.1103, ci = 1, wx = 4249, wy = 748, cm = 1414, cx = 0.4434, cy = 0.3485 },
    { id = 70, n = "Uldaman", raid = false, players = 10, m = 1418, x = 0.4423, y = 0.1221, ci = 0, wx = -6092, wy = -3179, dx = 0.3521, dy = 0.1029, cm = 1415, cx = 0.5449, cy = 0.5778 },
    { id = 90, n = "Gnomeregan", raid = false, players = 10, m = 1426, x = 0.1767, y = 0.3915, ci = 0, wx = -5163, wy = 932, cm = 1415, cx = 0.4281, cy = 0.5382 },
    { id = 109, n = "Sunken Temple", raid = false, players = 20, m = 1435, x = 0.7, y = 0.5291, ci = 0, wx = -10430, wy = -3829, dx = 0.773, dy = 0.3592, cm = 1415, cx = 0.5633, cy = 0.7626 },
    { id = 189, n = "Scarlet Monastery", raid = false, players = 10, m = 1420, x = 0.8508, y = 0.3138, ci = 0, wx = 2892, wy = -811, cm = 1415, cx = 0.4776, cy = 0.1949 },
    { id = 209, n = "Zul'Farrak", raid = false, players = 10, m = 1446, x = 0.3873, y = 0.199, ci = 1, wx = -6791, wy = -2891, cm = 1414, cx = 0.5423, cy = 0.7985 },
    { id = 229, n = "Blackrock Spire", raid = false, players = 10, m = 1428, x = 0.3299, y = 0.2517, ci = 0, wx = -7523, wy = -1233, cm = 1415, cx = 0.4896, cy = 0.6387 },
    { id = 229, n = "Blackrock Spire", raid = false, players = 10, m = 1427, x = 0.4079, y = 0.9563, ci = 0, wx = -7523, wy = -1233, cm = 1415, cx = 0.4896, cy = 0.6387 },
    { id = 230, n = "Blackrock Depths", raid = false, players = 5, m = 1428, x = 0.226, y = 0.0752, ci = 0, wx = -7178, wy = -929, cm = 1415, cx = 0.4809, cy = 0.6241 },
    { id = 230, n = "Blackrock Depths", raid = false, players = 5, m = 1427, x = 0.2715, y = 0.7248, ci = 0, wx = -7178, wy = -929, cm = 1415, cx = 0.4809, cy = 0.6241 },
    { id = 249, n = "Onyxia's Lair", raid = true, players = 40, m = 1445, x = 0.523, y = 0.7614, ci = 1, wx = -4698, wy = -3721, dx = 0.529, dy = 0.7771, cm = 1414, cx = 0.5649, cy = 0.7132 },
    { id = 289, n = "Scholomance", raid = false, players = 5, m = 1422, x = 0.6968, y = 0.7341, ci = 0, wx = 1262, wy = -2579, dx = 0.6905, dy = 0.7297, cm = 1415, cx = 0.5278, cy = 0.2644 },
    { id = 309, n = "Zul'Gurub", raid = true, players = 20, m = 1434, x = 0.5399, y = 0.1757, ci = 0, wx = -11916, wy = -1225, cm = 1415, cx = 0.4893, cy = 0.826 },
    { id = 329, n = "Stratholme", raid = false, players = 5, m = 1423, x = 0.2609, y = 0.1044, ci = 0, wx = 3392, wy = -3378, cm = 1415, cx = 0.5505, cy = 0.1736 },
    { id = 349, n = "Maraudon", raid = false, players = 10, m = 1443, x = 0.2925, y = 0.6253, ci = 1, wx = -1423, wy = 2918, dx = 0.291, dy = 0.6287, cm = 1414, cx = 0.3845, cy = 0.5797 },
    { id = 389, n = "Ragefire Chasm", raid = false, players = 10, m = 1454, x = 0.5296, y = 0.4887, ci = 1, wx = 1817, wy = -4423, cm = 1414, cx = 0.584, cy = 0.4477 },
    { id = 409, n = "Molten Core", raid = true, players = 40, m = 1428, x = 0.2629, y = 0.2455, ci = 0, wx = -7511, wy = -1037, cm = 1415, cx = 0.484, cy = 0.6382 },
    { id = 409, n = "Molten Core", raid = true, players = 40, m = 1427, x = 0.3199, y = 0.9483, ci = 0, wx = -7511, wy = -1037, cm = 1415, cx = 0.484, cy = 0.6382 },
    { id = 429, n = "Dire Maul", raid = false, players = 5, m = 1444, x = 0.6204, y = 0.3327, ci = 1, wx = -3908, wy = 1130, cm = 1414, cx = 0.4331, cy = 0.681 },
    { id = 469, n = "Blackwing Lair", raid = true, players = 40, m = 1428, x = 0.325, y = 0.3238, ci = 0, wx = -7663, wy = -1219, cm = 1415, cx = 0.4892, cy = 0.6447 },
    { id = 509, n = "Ruins of Ahn'Qiraj", raid = true, players = 20, m = 1451, x = 0.2903, y = 0.9282, ci = 1, wx = -8114, wy = 1526, cm = 1414, cx = 0.4223, cy = 0.8525 },
    { id = 531, n = "Ahn'Qiraj Temple", raid = true, players = 40, m = 1451, x = 0.2902, y = 0.927, ci = 1, wx = -8112, wy = 1527, cm = 1414, cx = 0.4223, cy = 0.8524 },
    { id = 533, n = "Naxxramas", raid = true, players = 40, m = 1423, x = 0.3426, y = 0.1948, ci = 0, wx = 3133, wy = -3730, cm = 1415, cx = 0.5605, cy = 0.1847 },
    { id = 2959, n = "City of Dalaran", raid = false, players = 0, m = 1416, x = 0.2169, y = 0.6836, ci = 0, wx = 224, wy = 176, cm = 1415, cx = 0.4495, cy = 0.3086 },
    { id = 2998, n = "Excavation Site: Wetlands", raid = false, players = 0, m = 1437, x = 0.4779, y = 0.5631, ci = 0, wx = -3700, wy = -2366, cm = 1415, cx = 0.5218, cy = 0.4758 },
    { id = 2999, n = "Ruins of Lordaeron", raid = false, players = 0, m = 1420, x = 0.6325, y = 0.675, ci = 0, wx = 1804, wy = 175, cm = 1415, cx = 0.4496, cy = 0.2413 },
    { id = 3065, n = "The Hall of Thanes", raid = false, players = 0, m = 1426, x = 0.6504, y = 0.0892, ci = 0, wx = -4170, wy = -1401, cm = 1415, cx = 0.4943, cy = 0.4959 },
}
