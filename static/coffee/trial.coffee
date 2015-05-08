class Trial
  startTime: null
  rt: null
  acc: null
  bonus: null
  next: null
  timeout: null
  myState: null

  handleSpacebar: (event) =>
    if event.keyCode is 32
      removeEventListener "keydown", @handleSpacebar
      e.doNext()

  handleButtonPress: (event) =>
    if event.keyCode in @keys # it's one of our legal responses
      removeEventListener "keydown", @handleButtonPress
      @rt = performance.now() - @startTime
      @acc = if event.keyCode == @cresp then 1 else 0
      @computeBonus() 
      clearTimeout @timeout
      psiTurk.recordTrialData [@trialIdGlobal, @trialIdBlock, @blockID, @context, @target, @cresp, @rt, @acc, @bonus]
      @showFeedback()

  constructor:(@context, @target, @keys, @cresp, @contextColor="black", @targetColor="black", @timeoutDur=10000)-> 

  computeBonus: => 
    @bonus = if @acc is 1 then 100 else -50 
    @bonus = @bonus - @rt * 0.1
    e.state.blockBonus = e.state.blockBonus + @bonus
    e.state.globalBonus = e.state.globalBonus + @bonus

  run: (state) => 
    r.clearScreen() 
    @startTime = performance.now() + e.config.iti + e.config.contextDur
    r.renderText @context, @contextColor
    setTimeout r.clearScreen, e.config.contextDur
    setTimeout (=> r.renderText @target, @targetColor), e.config.iti + e.config.contextDur
    setTimeout @enableInput, e.config.iti + e.config.contextDur
    
  timedOut: =>
    r.clearScreen()
    r.renderText "Timed out! -300 points! Press spacebar to continue."
    psiTurk.recordTrialData {'myID': @myID, 'context': @context, 'target': @target, 'cresp': @cresp, 'rt': @rt, 'acc': @acc, 'bonus': @bonus}
    addEventListener "keydown", @handleSpacebar

  showFeedback: =>
    r.clearScreen()
    if @acc is 1 
        feedbackText = "Correct! \n Your RT was #{ExtMath.round(@rt, 2)}ms! \n You get #{ExtMath.round(@bonus, 2)} points! \n\n Press the spacebar to continue."
    else 
        feedbackText = "Incorrect! \n Your RT was #{ExtMath.round(@rt,2)}ms! \n You get #{ExtMath.round(@bonus,2)} points! \n\n Press the spacebar to continue."
    r.renderText feedbackText
    addEventListener "keydown", @handleSpacebar


  enableInput: =>
    addEventListener "keydown", @handleButtonPress
    @timeout = setTimeout @timedOut, @timeoutDur

class PracticeLetterTrial extends Trial
  # remove timeout
  enableInput: => 
    addEventListener "keydown", @handleButtonPress

  showFeedback: =>
    r.clearScreen()
    if @acc is 1 
        feedbackText = "Correct!\n\n Press the spacebar to continue."
    else 
        feedbackText = "Incorrect! \n\n Press the spacebar to continue."
    r.renderText feedbackText
    addEventListener "keydown", @handleSpacebar

class TestLetterTrial extends PracticeLetterTrial
  showFeedback: =>
    r.clearScreen()
    if @acc is 1 
        e.state.currentStreak = e.state.currentStreak + 1
        feedbackText = "Correct (Streak: #{e.state.currentStreak})! (#{e.config.nTestAttempts-e.state.testId-1} attempts left)\n\n Press the spacebar to continue."
    else 
        e.state.currentStreak = 0
        feedbackText = "Incorrect! (#{e.config.nTestAttempts-e.state.testId-1} attempts left) \n\n Press the spacebar to continue."
    r.renderText feedbackText
    addEventListener "keydown", @handleSpacebar

class DotsTrial extends Trial
  constructor: (@context, @target, @keys, @cresp, @contextColor="black", @targetColor="black", @timeoutDur=10000)->
    super(@context, @target, @keys, @cresp, @contextColor, @targetColor, @timeoutDur=10000)

  run: (state) =>
    @myState = state # hang onto state
    r.clearScreen() 
    @startTime = performance.now() + @myState.config.iti + @myState.config.contextDur
    r.renderDots @context, @contextColor
    setTimeout r.clearScreen, @myState.config.contextDur
    setTimeout (=> r.renderDots @target, @targetColor), @myState.config.iti + @myState.config.contextDur
    setTimeout @enableInput, @myState.config.iti+@myState.config.contextDur
