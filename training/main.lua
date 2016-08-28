#!/usr/bin/env th

require 'torch'
require 'optim'
require 'paths'
require 'xlua'
require 'json'

function  saveJson(fileName, data)
   local file = assert(io.open(fileName, "w"))
   file:write(json.encode.encode(data))
   file:close()
end

local opts = paths.dofile('opts.lua')
local checkpoints = require 'checkpoints'
local DataLoader = require 'dataloader'
opt = opts.parse(arg)
print(opt)


if opt.cuda then
   require 'cutorch'
   cutorch.setDevice(opt.device)
end

saveJson(paths.concat(opt.save, 'opts.json'), opt)

print('Saving everything to: ' .. opt.save)
torch.setdefaulttensortype('torch.FloatTensor')
torch.manualSeed(opt.manualSeed)

-- Data loading
centerCluster  = torch.rand(opt.nClasses, opt.embSize)
local trainLoader, valLoader = DataLoader.create(opt, centerCluster)
local models = require 'model'
local modelConfig = models.ModelConfig()
modelConfig:generateConfig(opt)
middleBlock = modelConfig:middleBlockSetup(opt)
criterion   = modelConfig:critertionSetup(opt)

local Trainer = require 'train'
local trainer = Trainer(opt)
local Test    = require 'testVerify'
local tester = Test(opt)

epoch = 1
testData = {}
testData.bestVerAcc = 0
testData.bestEpoch = 0
testData.testVer = 0
testData.diffAcc = 0

for e = opt.epochNumber, opt.nEpochs do
   local sucess = trainer:train(trainLoader, modelConfig)
   if not sucess then break end
--    model = Trainer:saveModel(model)
   testData.testVer = tester:test(valLoader)
   local bestModel = false
   if testData.bestVerAcc < testData.testVer then
      print(' * Best model ', testData.testVer)
      bestModel = true
      testData.diffAcc = testData.testVer - testData.bestVerAcc
      testData.bestVerAcc = testData.testVer
      testData.bestEpoch  = epoch
   end
   model = checkpoints.save(epoch, model, optimState, bestModel, opt)
   if opt.checkEpoch > 0 and epoch > opt.checkEpoch then
      if testData.bestVerAcc < opt.checkValue then break end -- model does not converge, break it
   end
   epoch = epoch + 1
end

