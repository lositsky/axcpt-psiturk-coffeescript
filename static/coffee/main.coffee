class Experiment
  state: null
  config: null

  constructor: (@config) ->
    @state = 
      blockId : 0
      trialIdGlobal : 0 
      aPraxId: 0
      bPraxId: 0
      testId: 0
      blockBonus: 0
      globalBonus: 0
      currentStreak: 0
      phase: "initialInstructions"

    @config.nTrials = @config.blockSize * @config.nBlocks
    @config.payoffId = 
    @createInitialState
    r.createDrawingContext()
    @createTrialTypes() 
    @shuffleTrials() 

  updateBonusAndSave: () ->
    psiTurk.computeBonus 'compute_bonus', ->
      psiTurk.saveData() 


  shuffleTrials: ->
    console.log @config.condition
    trialCounts = (td * @config.blockSizeFreq for td in @config.trialDist)    
    console.log trialCounts
    # http://stackoverflow.com/questions/5685449/nested-array-comprehensions-in-coffeescript
    if @config.blockSize is 2*@config.blockSizeFreq
      trialOrderBlock1 = [] 
      trialOrderBlock1 = trialOrderBlock1.concat i for [1..tc] for tc, i in trialCounts
      trialOrderBlock1.shuffle()
      trialOrderBlock2 = [] 
      trialOrderBlock2 = trialOrderBlock2.concat i for [1..tc] for tc, i in trialCounts
      trialOrderBlock2.shuffle()
      @trialOrderBlock = trialOrderBlock1.concat trialOrderBlock2
    else if @config.blockSize is @config.blockSizeFreq
      @trialOrderBlock = [] 
      @trialOrderBlock = @trialOrderBlock.concat i for [1..tc] for tc, i in trialCounts
      @trialOrderBlock.shuffle()
    console.log @trialOrderBlock
    if (@state.blockId is 0)
      @trialOrder = @trialOrderBlock
    else
      @trialOrder = @trialOrder.concat @trialOrderBlock
    console.log @trialOrder  
    

  handleSpacebar: (event) =>
    if event.keyCode is 32
      removeEventListener "keydown", @handleSpacebar
      @state.instructionSlide = @state.instructionSlide + 1 
      @showInstructions()

  handleSpacebarBlockEnd: (event) =>
    if event.keyCode is 32
      removeEventListener "keydown", @handleSpacebarBlockEnd
      @trialTypes[@trialOrder[@state.trialIdGlobal]].run(this)

  setState: (state) ->
    @state = state

  run: ->

    @doNext() 

  doNext: ->
    r.clearScreen()
    switch @state.phase
      when "initialInstructions"
        @state.instructionSlide = 0
        @showInstructions()

      when "APractice"
        @state.aPraxId = @state.aPraxId + 1
        @state.trialIdGlobal = @state.trialIdGlobal + 1
        if (@state.aPraxId < @config.nPraxTrials)
          setTimeout (=> @praxTrialTypes[@aPrax[@state.aPraxId]].run()), @config.iti
        else 
          @state.instructionSlide = 4
          @showInstructions()

      when "BPractice"
        @state.bPraxId = @state.bPraxId + 1
        @state.trialIdGlobal = @state.trialIdGlobal + 1
        if (@state.bPraxId < @config.nPraxTrials) 
          setTimeout (=> @praxTrialTypes[@bPrax[@state.bPraxId]].run()), @config.iti
        else 
          @state.instructionSlide = 6
          @showInstructions()

      when "test"
        @state.testId = @state.testId + 1
        @state.trialIdGlobal = @state.trialIdGlobal + 1
        # if we've hit our streak
        if (@state.currentStreak is @config.testStreakToPass)
          psiTurk.recordUnstructuredData("trialsToLearn", @state.testId)
          @state.instructionSlide = 8
          @showInstructions() 
        # haven't hit streak but haven't run out of attempts
        else if (@state.testId < @config.nTestAttempts) 
          setTimeout (=> @testTrialTypes[@testTrialOrder[@state.testId]].run()), @config.iti
        # ran out of attempts
        else 
          @endExperimentFail()

      when "experiment"
        @state.trialIdGlobal = @state.trialIdGlobal + 1
        if (@state.trialIdGlobal is @config.nTrials)
          @endExperimentTrials()
        else if ((@state.globalBonus/@config.pointsPerDollar) >= @config.maxBonus)
          @endExperimentMoney()
        else if ((@state.trialIdGlobal %% @config.blockSize) is 0) 
          @state.blockId = @state.blockId + 1
          @shuffleTrials() 
          @blockFeedback() 
        else 
          setTimeout (=> @trialTypes[@trialOrder[@state.trialIdGlobal]].run()), @config.iti

  endExperiment: (event) =>
    removeEventListener "keydown", @endExperiment
    psiTurk.showPage('postquestionnaire.html')
    

  endExperimentMoney: =>
    r.clearScreen()
    r.renderText "Congratulations! You have achieved the maximum possible bonus.\n
                  You will be paid $#{@config.minPayment + @config.maxBonus} for your time.\n
                  If you have any questions, email #{@config.experimenterEmail}.\n
                  Please press any key to continue."
    psiTurk.recordUnstructuredData('expEndReason', 'maxMoney')
    addEventListener "keydown", @endExperiment
    

  endExperimentTrials: =>
    r.clearScreen()
    cashBonus = if @state.globalBonus < 0 then 0 else ExtMath.round(@state.globalBonus / @config.pointsPerDollar, 2)
    r.renderText "Thank you! This concludes the experiment.\n
                  Based on achieving #{ExtMath.round(@state.globalBonus,2)} points,\n
                  you will be paid $#{cashBonus} for your time.\n
                  If you have any questions, email #{@config.experimenterEmail}.\n
                  Please press any key to continue."
    psiTurk.recordUnstructuredData('expEndReason', 'trials')
    addEventListener "keydown", @endExperiment

  endExperimentFail: => 
    r.clearScreen()
    r.renderText "Unfortunately, you were unable to get #{@config.testStreakToPass} correct in a row.\n
                  This means that you cannot continue with the experiment.\n
                  You will receive $#{@config.minPayment} for your time.\n
                  If you have any questions, email #{@config.experimenterEmail}.\n
                  Please press any key to continue."
    addEventListener "keydown", @endExperiment

  startExperiment: ->
    psiTurk.recordUnstructuredData('trialDist', @config.trialDist)
    @state.phase = "experiment"
    psiTurk.finishInstructions()
    @state.trialIdGlobal = 0 # reset so that trial IDs start at 0 uniformly
    # initialize bonuses
    @state.globalBonus = 0 
    @state.bloclBonus = 0 
    @trialTypes[@trialOrder[0]].run()

  blockFeedback: ->
    r.clearScreen()
    # otherwise do feedback and next trial
    feedbackText = "Done with block #{@state.blockId} / #{@config.nBlocks}: \n \n
    You earned #{ExtMath.round(@state.blockBonus, 2)} / #{@config.correctPoints*@config.blockSize} bonus points!\n"
    r.renderText feedbackText, "black", 0, -200
    @state.blockBonus = 0
    @updateBonusAndSave()
    setTimeout (-> r.renderText "Press the spacebar when you are ready to continue.", "black", 0, 0 ), @config.blockRestDur*1000
    setTimeout (=> addEventListener "keydown", @handleSpacebarBlockEnd), @config.blockRestDur*1000
    

  showInstructions: ->
    switch @state.instructionSlide
      when 0
        r.renderText "Welcome to the experiment!\n
                      In this experiment, you will press keys based on pairs of #{@stimsName}.\n
                      The two #{@stimsName} in each pair will be separated by a blank screen.\n
                      There will be one correct key for each pair of #{@stimsName}.\n\n", "black", 0, -200
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 0 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 1
        r.clearScreen()
        r.renderText "First, you will learn the rules mapping #{@stimsName} to keys.\n
                      Then, we will test that you learned the rules.\n
                      If you fail, the HIT will end and you will earn the minimum payment ($#{@config.minPayment}).\n
                      If you succeed, you will compete for an additional bonus (up to $#{@config.maxBonus}).\n
                      You response keys will be '4' and '8'. \n
                      You should put your left index finger on '4' and right index finger on '8' now. \n\n", "black", 0, -200
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 100 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 2
        r.clearScreen()
        r.renderText "Here is the first rule:\n\n
                      followed by         -->  press the '4' key\n", "black", 0, -240
        r.renderText " followed by         -->  press the '8' key\n\n
                      Now you will get a chance to practice.", "black", 0, -115
        @renderStimInstruct @stimuli[0], "blue", -275, -165 # A 
        @renderStimInstruct @stimuli[1], "blue", -55, -165 # X
        @renderStimInstruct @stimuli[0], "blue", -275, -115 # A
        @renderStimInstruct @stimuli[2], "blue", -55, -115 # Y
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 20 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 3
        @state.phase = "APractice"
        @praxTrialTypes[@aPrax[0]].run()
      when 4
        r.clearScreen()
        r.renderText "Here is the second rule:\n\n
                      followed by         -->  press the '8' key\n","black", 0, -240
        r.renderText " followed by         -->  press the '4' key\n\n
                      Now you will get a chance to practice.", "black", 0, -115
        @renderStimInstruct @stimuli[3], "blue", -275, -165 # B
        @renderStimInstruct @stimuli[1], "blue", -55, -165 # X
        @renderStimInstruct @stimuli[3], "blue", -275, -115 # B 
        @renderStimInstruct @stimuli[2], "blue", -55, -115 # Y
        # @renderStimInstruct @stimuli[3], "blue", -250, -165
        # @renderStimInstruct @stimuli[2], "blue", -50, -165
        # @renderStimInstruct @stimuli[3], "blue", -250, -130
        # @renderStimInstruct @stimuli[1], "blue", -50, -130
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 20 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 5
        @state.phase = "BPractice"
        @praxTrialTypes[@bPrax[0]].run()
      when 6
        r.clearScreen()
        r.renderText "Now, we will test that you have learned the rules.\n
                      You will see a sequence of trials. Your goal is to get #{@config.testStreakToPass} correct in a row.\n
                      You will have #{@config.nTestAttempts} trials total. If you get #{@config.testStreakToPass} correct in a row, you can compete\n
                      for a bonus of up to $#{@config.maxBonus}. If you get to #{@config.nTestAttempts} without getting #{@config.testStreakToPass} in a row, \n
                      the HIT will end and you will get the minimum payment ($#{@config.minPayment}).\n\n
                      As a reminder, here are the rules: \n", "black", 0, -270 # -215
        @renderRules(0, 0) # 45
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 215 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 7
        r.clearScreen()
        @state.phase = "test"
        @testTrialTypes[@testTrialOrder[0]].run()
      when 8
        r.clearScreen()
        r.renderText "Congratulations! You have learned the rules.\n
                      You will now see #{@config.nBlocks} blocks with #{@config.blockSize} trials in each block.\n\n
                      You will get #{@config.correctPoints} points for a correct response.\n
                      You will receive $1 for each #{@config.pointsPerDollar} points.\n\n
                      You have up to #{@config.deadline} seconds to respond on each trial,\n
                      but if you respond fast, you can finish the HIT in less than 18 minutes.\n
                      If you respond slowly, you can finish the HIT in 30 minutes.\n\n", "black", 0, -260
                      # The HIT will end when you have completed the #{@config.nBlocks} blocks.\n\n                      
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 100 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 9
        r.clearScreen()
        r.renderText "As a reminder, here are the rules:", "black", 0, -240 
        @renderRules(0, -200)
        r.renderText  "As soon as you press a key, \n
                      we will give feedback about your speed and accuracy\n
                      and the game will continue to the next trial automatically\n
                      (you do NOT need to press spacebar during the block).\n", "black", 0, 0
        setTimeout (-> r.renderText "Press the spacebar to continue.", "black", 0, 180 ), @config.spacebarTimeout
        setTimeout (=> addEventListener "keydown", @handleSpacebar), @config.spacebarTimeout
      when 10
        r.clearScreen()
        @startExperiment()

  renderRules : (xoffset=0, yoffset=0)->
    r.renderText "followed by         -->  press the '8' key\n", "black", xoffset, 0+yoffset
    r.renderText "followed by         -->  press the '4' key\n", "black", xoffset, 50+yoffset
    r.renderText "followed by         -->  press the '4' key\n", "black", xoffset, 100+yoffset
    r.renderText "followed by         -->  press the '8' key", "black", xoffset, 150+yoffset
    @renderStimInstruct e.stimuli[0], "blue", -270+xoffset, 0+yoffset # A
    @renderStimInstruct e.stimuli[2], "blue", -50+xoffset, 0+yoffset # Y
    @renderStimInstruct e.stimuli[0], "blue", -270+xoffset, 50+yoffset # A
    @renderStimInstruct e.stimuli[1], "blue", -50+xoffset, 50+yoffset # X
    @renderStimInstruct e.stimuli[3], "blue", -270+xoffset, 100+yoffset # B
    @renderStimInstruct e.stimuli[2], "blue", -50+xoffset, 100+yoffset # Y
    @renderStimInstruct e.stimuli[3], "blue", -270+xoffset, 150+yoffset # B
    @renderStimInstruct e.stimuli[1], "blue", -50+xoffset, 150+yoffset # X
# 0, 35, 70, 105


  createTrialTypes: -> 
    @stimuli.shuffle() 
    @trialTypes = [new Trial("A", "X", @renderStimTrial, @stimuli[0], @stimuli[1], [52,56], 52, "blue", "blue"), 
                  new Trial("A", "Y", @renderStimTrial, @stimuli[0], @stimuli[2], [52,56], 56, "blue", "blue"), 
                  new Trial("B", "X", @renderStimTrial, @stimuli[3], @stimuli[1], [52,56], 56, "blue", "blue"),
                  new Trial("B", "Y", @renderStimTrial, @stimuli[3], @stimuli[2], [52,56], 52, "blue", "blue")]

    @praxTrialTypes = [new PracticeTrial("A", "X", @renderStimTrial, @stimuli[0], @stimuli[1], [52,56], 52, "blue", "blue"), 
                  new PracticeTrial("A", "Y", @renderStimTrial, @stimuli[0], @stimuli[2], [52,56], 56, "blue", "blue"), 
                  new PracticeTrial("B", "X", @renderStimTrial, @stimuli[3], @stimuli[1], [52,56], 56, "blue", "blue"),
                  new PracticeTrial("B", "Y", @renderStimTrial, @stimuli[3], @stimuli[2], [52,56], 52, "blue", "blue")]

    @testTrialTypes = [new TestTrial("A", "X", @renderStimTrial, @stimuli[0], @stimuli[1], [52,56], 52, "blue", "blue"), 
                  new TestTrial("A", "Y", @renderStimTrial, @stimuli[0], @stimuli[2], [52,56], 56, "blue", "blue"), 
                  new TestTrial("B", "X", @renderStimTrial, @stimuli[3], @stimuli[1], [52,56], 56, "blue", "blue"),
                  new TestTrial("B", "Y", @renderStimTrial, @stimuli[3], @stimuli[2], [52,56], 52, "blue", "blue")]


    praxCounts = (@config.nPraxTrials/2 for i in [1..2]) # uniform distr of AX and AY or practice, BX and BY also
    # http://stackoverflow.com/questions/5685449/nested-array-comprehensions-in-coffeescript

    @aPrax = [] 
    @bPrax = []
    
    @aPrax = @aPrax.concat i for [1..pc] for pc, i in praxCounts

    @bPrax = @bPrax.concat i+2 for [1..pc] for pc, i in praxCounts # i+2 because B trials are trialtypes 2,3

    @aPrax.shuffle()
    @bPrax.shuffle()

    testCounts = (@config.nTestAttempts/4 for i in [1..4]) # uniform distr on all 4 for the test attempts
    @testTrialOrder = []
    @testTrialOrder = @testTrialOrder.concat i for [1..tc] for tc, i in testCounts
    @testTrialOrder.shuffle()
  


class LettersExperiment extends Experiment  
  stimsName : "letters"
  # @stimuli = ["A","X","B","Y"] # eventually this should be the whole alphabet
  stimuli: ["B","C","D","F","G","H","J","K","L","M","N","P","Q","R","S","T","V","W","X","Y","Z"]

  renderStimInstruct : (stim, colour="black", xoffset=0, yoffset=0)->
    r.renderText stim, colour, xoffset, yoffset
  
  renderStimTrial : (stim, colour="black", xoffset=0, yoffset=0)=>
    r.renderText stim, colour, xoffset, yoffset, e.config.taskFontSize

class DotsExperiment extends Experiment  
  stimsName : "dots"
  # all except 0000 which make it hard to see color
  # @stimuli : [[0,0,0,1],[0,0,1,0],[0,0,1,1],[0,1,0,0],[0,1,0,1],[0,1,1,0],[0,1,1,1],[1,0,0,0],[1,0,0,1],[1,0,1,0],[1,0,1,1],[1,1,0,0],[1,1,0,1],[1,1,1,0],[1,1,1,1]]
  # all with 2 empty 2 filled => easy to use "both diagonal vs. both straight strategy"
  stimuli: [[0,0,1,1],[0,1,0,1],[0,1,1,0],[1,0,0,1],[1,0,1,0],[1,1,0,0]]
  # 3, 4, 5 and 6 filled dots out of 9 => too easy because of number of dots
  # stimuli: [[1,0,1,1,0,1,1,0,1], [0,1,0,1,1,1,0,1,0], [1,0,1,0,0,0,1,0,1], [0,0,0,1,1,1,0,0,0]]
  # 3 dots vertical and horizontal; 6 dots vertical and horizontal
  # stimuli: [[0,1,0,0,1,0,0,1,0], [0,0,0,1,1,1,0,0,0], [1,0,1,1,0,1,1,0,1], [1,1,1,0,0,0,1,1,1]]
  # the above is too easy, unless two of these are always cues and two of them always probes

  renderStimInstruct : (stim, colour="black", xoffset=0, yoffset=0)->
    r.renderDots stim, colour, xoffset, yoffset, 5, 7
  # r.renderDots stim, colour, xoffset, yoffset, 5, 13
  renderStimTrial : (stim, colour="black", xoffset=0, yoffset=0)->
    r.renderDots stim, colour, xoffset, yoffset, 15, 20
  # r.renderDots stim, colour, xoffset, yoffset, 15, 35

# window.Experiment = LettersExperiment
window.Experiment = DotsExperiment
window.Renderer = Renderer

