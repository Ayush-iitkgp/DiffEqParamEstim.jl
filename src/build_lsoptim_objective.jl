export build_lsoptim_objective

function build_lsoptim_objective(prob::DEProblem,t,data,alg;
                                 prob_generator = problem_new_parameters,
                                 kwargs...)
  vec_data = vec(data)
  cost_function = function (out,p)
  tmp_prob = prob_generator(prob,p)
  sol = solve(tmp_prob,alg;saveat=t,save_everystep=false,dense=false,kwargs...)
  fill_length = length(t)-length(sol)
  for i in 1:fill_length
    push!(sol.u,fill(NaN,size(prob.u0)))
  end
  y = vec(sol)
  out .= y .- vec_data
  end
end
