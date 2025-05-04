Rails.application.routes.draw do
  post "vm_build", to: "vm_build#create"
end
