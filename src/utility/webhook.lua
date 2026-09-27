return {
    send_webhook = function(self, title, message, content)
        task.spawn(xpcall, function()
            local webhook = persistent_data:get("automation_webhook", nil);
        
            if webhook then
                request({
                    Url = webhook,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = game:GetService("HttpService"):JSONEncode({
                        content = content or " ",
                        embeds = {
                            {
                                title = title,
                                description = message,
                                color = 6724044,
                                author = {
                                    name = "vanta",
                                }
                            }
                        },
                        username = "Vanta",
                        attachments = {},
                        flags = 4096
                    })
                })
                
            end;
        end, warn);
    end;
}