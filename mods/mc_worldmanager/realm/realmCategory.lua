realm.categories = {}

realm.categories["spawn"] = {
    visible = function(realm, player)
    end,
    joinable = function(realm, player)
    end
}

realm.categories["world"] = {
    visible = function(realm, player)
    end,
    joinable = function(realm, player)
    end
}

realm.categories["classroom"] = {
visible = function (realm, player)
end,
joinable = function (realm, player)
end
}

realm.categories["instanced"] = {
visible = function (realm, player)
end,
joinable = function (realm, player)
end
}


function Realm:SetCategory(category)
self:set_string("category", category)
end

function Realm:GetCategory()
return self:get_string("category")
end
