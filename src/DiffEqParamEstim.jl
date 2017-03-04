module DiffEqParamEstim

using DiffEqBase, LsqFit, LossFunctions, RecursiveArrayTools, ForwardDiff, Calculus


  ### LsqFit Method
  function lm_fit(prob::DEProblem,t,data,p0,alg;kwargs...)
    f = prob.f

    model = function (t,p)
      for i in eachindex(f.params)
        setfield!(f,f.params[i],p[i])
      end
      sol = solve(prob,alg;saveat=t,save_timeseries=false,dense=false,kwargs...)
      y = vecvec_to_mat(sol.u)
      vec(y)
    end
    curve_fit(model,t,vec(data),p0;kwargs...)
  end

  immutable DiffEqObjective{F,F2} <: Function
    cost_function::F
    cost_function2::F2
  end
  (f::DiffEqObjective)(x) = f.cost_function(x)
  (f::DiffEqObjective)(x,y) = f.cost_function2(x,y)


  # This function returns the DiffEqObjective which has 2 cost functions
  function build_loss_objective(prob::DEProblem,t,data,alg;
                                loss_func = L2DistLoss,
                                mpg_autodiff = false,
                                verbose = false,
                                verbose_steps = 100,
                                kwargs...)
    f = prob.f

    # Define first cost function
    cost_function = function (p)
      f = (t,u,du) -> prob.f(t,u,p,du)
      print(f)
      print(typeof(p))
      uEltype = eltype(p)    # type of u = type of p
      println(uEltype)
      u0 = [uEltype(prob.u0[i]) for i in 1:length(prob.u0)] #Convert u0 to type of p
      tspan = (uEltype(prob.tspan[1]),uEltype(prob.tspan[2]))  #tspan
      temp_prob = ODEProblem(f,u0,tspan)   #ReCreat the ODE Problem
      if alg == nothing
        sol = solve(temp_prob;saveat=t,save_timeseries=false,dense=false,kwargs...)
      else
        sol = solve(temp_prob,alg;saveat=t,save_timeseries=false,dense=false,kwargs...)
      end
      fill_length = length(t)-length(sol)   #length(t) = 200 length(sol) = 34
      for i in 1:fill_length
        push!(sol.u,fill(NaN,size(prob.u0)))
        #push!(sol.u,zeros(prob.u0))
      end
      y = vec(vecvec_to_mat(sol.u))
      norm(value(loss_func(),vec(data),vec(y)))
    end

    




    # Preprocessing for second cost_function
    if mpg_autodiff
      gcfg = ForwardDiff.GradientConfig(zeros(length(f.syms)))
      g! = (x, out) -> ForwardDiff.gradient!(out, cost_function, x, gcfg)
    else
      g! = (x, out) -> Calculus.finite_difference!(cost_function,x,out,:central)
    end

    if verbose
      count = 0 # keep track of # function evaluations
    end

    # Define second cost function
    cost_function2 = function (p,grad)
      if length(grad)>0
        g!(p,grad)
      end
      
      if verbose
        count::Int += 1
        if mod(count,verbose_steps) == 0
          println("f_$count($p)")
        end
      end

      cost_function(p)
    end
    
    DiffEqObjective(cost_function,cost_function2)
  end

  function build_lsoptim_objective(prob::DEProblem,t,data,alg;kwargs...)
    internal_data = vec(data)
    cost_function = function (p,out)
      f = (t,u,du) -> prob.f(t,u,p,du)
      uEltype = eltype(p)
      u0 = [uEltype(prob.u0[i]) for i in 1:length(prob.u0)]
      tspan = (uEltype(prob.tspan[1]),uEltype(prob.tspan[2]))
      temp_prob = ODEProblem(f,u0,tspan)
      if alg == nothing
        sol = solve(temp_prob;saveat=t,save_timeseries=false,dense=false,kwargs...)
      else
        sol = solve(temp_prob,alg;saveat=t,save_timeseries=false,dense=false,kwargs...)
      end
      fill_length = length(t)-length(sol)
      for i in 1:fill_length
        push!(sol.u,fill(NaN,size(prob.u0)))
        #push!(sol.u,zeros(prob.u0))
      end
      y = vec(vecvec_to_mat(sol.u))
      out .= y.-internal_data
    end
  end

  export lm_fit, build_loss_objective, build_lsoptim_objective, DiffEqObjective

end # module
